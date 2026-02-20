import CoreLocation
import SwiftUI

struct ProfileView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(FriendsStore.self) private var friendsStore
    @Environment(UploadManager.self) private var uploadManager

    @State private var userPosts: [ImagePost] = []
    @State private var isLoadingPosts = false
    @State private var showSignOutAlert = false

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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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
            .onChange(of: uploadManager.completedUploadCount) {
                Task { await loadPosts() }
            }
        }
    }

    // MARK: - Content

    private func profileContent(user: User) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                ProfileHeaderView(user: user) {
                    HStack(spacing: 16) {
                        ProfileStatItem(
                            value: userPosts.count + currentUserPendingCount,
                            label: "Posts"
                        )
                        ProfileStatItem(value: friendsStore.friends.count, label: "Friends")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                if !user.bio.isEmpty {
                    ProfileBioView(bio: user.bio)
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                }

                ProfilePostsSection(
                    isLoading: isLoadingPosts,
                    items: gridItems,
                    uploadedPosts: userPosts,
                    onRetry: { post in uploadManager.retryPost(post) },
                    onRemove: { post in uploadManager.removePost(post) },
                    emptyContent: {
                        ProfilePostsEmptyState(
                            icon: "camera",
                            title: "No photos yet",
                            subtitle: "Your photos will appear here."
                        )
                    }
                )
                .padding(.top, 16)
            }
        }
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
        guard let userId = authManager.userId,
              let user = authManager.currentProfile else { return }
        isLoadingPosts = true
        do {
            let rows: [PostRowWithoutLocation] = try await SupabaseManager.client
                .from("posts")
                .select(PostRowWithoutLocation.selectColumns)
                .eq("user_id", value: userId)
                .order("created_at", ascending: false)
                .execute()
                .value

            userPosts = rows.map { row in
                ImagePost(
                    id: row.id,
                    imageURL: SupabaseManager.imageURL(for: row.imagePath),
                    user: user,
                    caption: row.caption ?? "",
                    coordinate: CLLocationCoordinate2D(
                        latitude: row.latitude,
                        longitude: row.longitude
                    ),
                    locationName: row.locationName ?? "",
                    timestamp: ISO8601DateFormatter.flexibleParse(row.createdAt) ?? Date(),
                    distanceMeters: 0,
                    scope: PostScope(serverValue: row.scope)
                )
            }
        } catch {
            print("[ProfileView] Failed to load posts: \(error)")
        }
        isLoadingPosts = false
    }
}

// MARK: - Preview

#Preview {
    ProfileView()
        .environment(AuthManager())
        .environment(FriendsStore())
        .environment(MomentsStore())
        .environment(UploadManager())
}
