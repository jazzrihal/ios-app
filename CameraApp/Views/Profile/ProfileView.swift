import SwiftUI

struct ProfileView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(FriendsStore.self) private var friendsStore
    @Environment(UploadManager.self) private var uploadManager
    @Environment(PostMutationStore.self) private var postMutationStore
    @Environment(DefaultPostRepository.self) private var postRepository
    @Environment(CacheInvalidator.self) private var cacheInvalidator
    @Environment(DefaultNotificationRepository.self) private var notificationRepository

    @State private var userPosts: [ImagePost] = []
    @State private var isLoadingPosts = false
    /// True only during a user-initiated pull-to-refresh. Center overlays must not
    /// appear while this is true — the native pull spinner is the only indicator.
    @State private var isRefreshing = false
    @State private var isLoadingMore = false
    @State private var hasMorePages = true
    @State private var showSignOutAlert = false
    @State private var unreadCount: Int = 0
    @State private var showActivity = false

    private let pageSize = 20

    private var currentUsername: String? {
        authManager.currentProfile?.username
    }

    var body: some View {
        NavigationStack {
            Group {
                if let user = authManager.currentProfile {
                    profileContent(user: user)
                } else {
                    ProgressView("Loading profile…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationDestination(isPresented: $showActivity) {
                ActivityView(repository: notificationRepository, unreadBadge: $unreadCount)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showActivity = true } label: {
                        Image(systemName: "bell")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .overlay(alignment: .topTrailing) {
                                if unreadCount > 0 {
                                    Circle()
                                        .fill(.red)
                                        .frame(width: 8, height: 8)
                                        .offset(x: 4, y: -4)
                                }
                            }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if currentUserPendingCount > 0 {
                            showSignOutAlert = true
                        } else {
                            Task { await authManager.signOut() }
                        }
                    } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .alert(
                "Unsaved uploads",
                isPresented: $showSignOutAlert
            ) {
                Button("Sign Out", role: .destructive) {
                    Task { await authManager.signOut() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(
                    "You have \(currentUserPendingCount) photo\(currentUserPendingCount == 1 ? "" : "s") that"
                        + " haven't been uploaded yet. Signing out will discard them."
                )
            }
            .task { await loadPosts() }
            .task { await loadUnreadCount() }
            .onChange(of: uploadManager.completedUploadCount) {
                if let userId = authManager.userId {
                    cacheInvalidator.postUploaded(userId: userId)
                }
                Task { await loadPosts() }
            }
        }
    }

    // MARK: - Content

    private func profileContent(user: User) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                ProfileHeaderView(user: user) {
                    HStack(spacing: AppStyle.Padding.screenHorizontal) {
                        ProfileStatItem(
                            value: userPosts.filter(\.isOwnPost).count + currentUserPendingCount,
                            label: "Posts"
                        )
                        ProfileStatItem(value: friendsStore.friends.count, label: "Friends")
                    }
                }
                .padding(.horizontal, AppStyle.Padding.screenHorizontal)
                .padding(.top, AppStyle.Spacing.medium)

                if !user.bio.isEmpty {
                    ProfileBioView(bio: user.bio)
                        .padding(.horizontal, AppStyle.Padding.screenHorizontal)
                        .padding(.top, AppStyle.Spacing.row)
                }

                ProfilePostsSection(
                    isLoading: isLoadingPosts,
                    items: gridItems,
                    uploadedPosts: userPosts,
                    onRetry: { post in uploadManager.retryPost(post) },
                    onRemove: { post in uploadManager.removePost(post) },
                    hasMorePages: hasMorePages,
                    isLoadingMore: isLoadingMore,
                    onLoadMore: { Task { await loadNextPage() } },
                    emptyContent: {
                        EmptyStateView(
                            icon: "camera",
                            title: "No photos yet",
                            subtitle: "Your photos will appear here."
                        )
                    }
                )
                .padding(.top, AppStyle.Padding.screenHorizontal)
            }
        }
        .tabLoadable(
            isLoading: isLoadingPosts && userPosts.isEmpty,
            isRefreshing: isRefreshing,
            onRefresh: {
                guard !isRefreshing else { return }
                isRefreshing = true
                defer { isRefreshing = false }

                if let userId = authManager.userId {
                    postRepository.invalidateUserPosts(userId)
                }
                await loadPosts()
            }
        )
    }

    // MARK: - Grid Items

    private var currentUserPendingCount: Int {
        let uid = authManager.userId
        return uploadManager.pendingPosts.filter { uid == nil || $0.userId == uid }.count
    }

    /// Pending uploads first (newest at top), then server-side posts.
    /// Only includes pending posts belonging to the current user.
    private var gridItems: [ProfileGridItem] {
        let currentUserId = authManager.userId
        let pendingItems: [ProfileGridItem] = uploadManager.pendingPosts
            .filter { currentUserId == nil || $0.userId == currentUserId }
            .map { post in
                let image: UIImage? = {
                    guard let data = uploadManager.loadImage(fileName: post.localImageFileName)
                    else { return nil }
                    return UIImage(data: data)
                }()
                return .pending(post, image)
            }
        let uploadedItems: [ProfileGridItem] = userPosts.map { .uploaded($0) }
        return pendingItems + uploadedItems
    }

    // MARK: - Data Loading

    private func loadPosts() async {
        guard let userId = authManager.userId else { return }
        isLoadingPosts = true
        hasMorePages = true
        do {
            let loadedPosts = try await postRepository.userPostsAndPins(
                userId: userId, pageSize: pageSize, pageOffset: 0
            )
            userPosts = applyPinnedUserContext(to: loadedPosts)
            postMutationStore.seedFromPosts(userPosts)
            hasMorePages = userPosts.count == pageSize
        } catch {
            print("[ProfileView] Failed to load posts: \(error)")
        }
        isLoadingPosts = false
    }

    private func loadUnreadCount() async {
        do {
            unreadCount = try await notificationRepository.getUnreadCount()
        } catch {
            print("[ProfileView] Failed to load unread count: \(error)")
        }
    }

    private func loadNextPage() async {
        guard hasMorePages, !isLoadingMore, let userId = authManager.userId else { return }
        isLoadingMore = true
        do {
            let loadedPosts = try await postRepository.userPostsAndPins(
                userId: userId, pageSize: pageSize, pageOffset: userPosts.count
            )
            let newPosts = applyPinnedUserContext(to: loadedPosts)
            postMutationStore.seedFromPosts(newPosts)
            userPosts.append(contentsOf: newPosts)
            hasMorePages = newPosts.count == pageSize
        } catch {
            print("[ProfileView] Failed to load more posts: \(error)")
        }
        isLoadingMore = false
    }

    private func applyPinnedUserContext(to posts: [ImagePost]) -> [ImagePost] {
        guard let username = currentUsername else { return posts }
        return posts.map { post in
            guard post.isPinnedByUser else { return post }
            var normalizedPost = post
            normalizedPost.pinnedByUsername = username
            return normalizedPost
        }
    }
}

// MARK: - Preview

#Preview {
    ProfileView()
        .environment(AuthManager())
        .environment(FriendsStore())
        .environment(MomentsStore())
        .environment(PostMutationStore())
        .environment(UploadManager())
        .environment(PreviewContainer.postRepository)
        .environment(CacheInvalidator())
        .environment(DefaultNotificationRepository())
}
