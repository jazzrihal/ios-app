import CoreLocation
import NukeUI
import SwiftUI

// MARK: - Post Detail View

struct PostDetailView: View {
    @Environment(MomentsStore.self) private var momentsStore
    @Environment(PostMutationStore.self) private var postMutationStore
    @Environment(AuthManager.self) private var authManager
    @Environment(UploadManager.self) private var uploadManager
    @Environment(DefaultPostRepository.self) private var postRepository
    @Environment(CacheInvalidator.self) private var cacheInvalidator
    @Environment(DefaultBadgeRepository.self) private var badgeRepository
    @Environment(\.dismiss) private var dismiss

    private let source: Source

    @State private var viewModel: PostDetailViewModel?
    @State private var showEditPostFlow = false
    @State private var showDeleteConfirmation = false
    @State private var mutationError: String?
    @State private var isMutatingPost = false

    enum Source {
        case uploaded(posts: [ImagePost], initialIndex: Int, queryDate: Date)
        case pending(post: PendingPost, image: UIImage)
    }

    init(posts: [ImagePost], initialIndex: Int, queryDate: Date) {
        source = .uploaded(posts: posts, initialIndex: initialIndex, queryDate: queryDate)
        _viewModel = State(initialValue: PostDetailViewModel(
            posts: posts,
            initialIndex: initialIndex,
            queryDate: queryDate
        ))
    }

    init(pendingPost: PendingPost, image: UIImage) {
        source = .pending(post: pendingPost, image: image)
        _viewModel = State(initialValue: nil)
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            switch source {
            case .uploaded:
                if let viewModel {
                    TabView(selection: Binding(
                        get: { viewModel.currentIndex },
                        set: { viewModel.currentIndex = $0 }
                    )) {
                        ForEach(Array(viewModel.posts.enumerated()), id: \.element.id) { index, post in
                            postPage(
                                imageContent: { remoteImage(url: post.imageURL) },
                                meta: PostPageMeta(
                                    user: post.user,
                                    caption: post.caption,
                                    timestamp: post.timestamp,
                                    locationName: post.locationName,
                                    pinnedByUsername: post.pinnedByUsername,
                                    linkToProfile: true
                                )
                            )
                            .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))

                    actionBar(viewModel: viewModel)
                }

            case let .pending(post, image):
                postPage(
                    imageContent: { localImage(uiImage: image) },
                    meta: PostPageMeta(
                        user: authManager.currentProfile,
                        caption: post.caption ?? "",
                        timestamp: post.createdAt,
                        locationName: post.locationName ?? "",
                        pinnedByUsername: nil,
                        linkToProfile: false
                    )
                )

                pendingActionBar(for: post)
            }
        }
        .background(Color(.systemBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            if shouldShowOwnerMenu {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showEditPostFlow = true
                        } label: {
                            Label("Edit Post", systemImage: "pencil")
                        }
                        .accessibilityIdentifier("EditPostMenuAction")

                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete Post", systemImage: "trash")
                        }
                        .accessibilityIdentifier("DeletePostMenuAction")
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityIdentifier("PostOptionsMenuButton")
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { viewModel?.showShareSheet ?? false },
            set: { viewModel?.showShareSheet = $0 }
        )) {
            if let viewModel {
                ShareSheet(items: [viewModel.post.imageURL])
            }
        }
        .fullScreenCover(isPresented: $showEditPostFlow) {
            if let editingPost = currentUploadedPost, viewerOwnsCurrentUploadedPost {
                PostPreviewView(
                    editingPost: editingPost,
                    onDone: { showEditPostFlow = false },
                    onSaved: { dismiss() }
                )
            }
        }
        .alert("Delete Post?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task { await deleteCurrentPost() }
            }
        } message: {
            Text("This will permanently remove your post.")
        }
        .alert("Couldn't delete post", isPresented: Binding(
            get: { mutationError != nil },
            set: { if !$0 { mutationError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(mutationError ?? "Unknown error.")
        }
        .onChange(of: viewModel?.shouldDismiss) { _, shouldDismiss in
            if shouldDismiss == true { dismiss() }
        }
        .onAppear {
            viewModel?.mutationStore = postMutationStore
            viewModel?.badgeRepository = badgeRepository
        }
        .task {
            guard let viewModel else { return }
            await viewModel.loadBadges(postId: viewModel.post.id)
        }
        .onChange(of: viewModel?.currentIndex) {
            guard let viewModel else { return }
            Task { await viewModel.loadBadges(postId: viewModel.post.id) }
        }
    }

    private var currentUploadedPost: ImagePost? {
        guard case .uploaded = source else { return nil }
        return viewModel?.post
    }

    private var viewerOwnsCurrentUploadedPost: Bool {
        guard let post = currentUploadedPost, let authUserId = authManager.userId else { return false }
        return post.user.id == authUserId
    }

    private var shouldShowOwnerMenu: Bool {
        viewerOwnsCurrentUploadedPost && !isMutatingPost
    }

    // MARK: - Post Page

    private struct PostPageMeta {
        let user: User?
        let caption: String
        let timestamp: Date
        let locationName: String
        let pinnedByUsername: String?
        let linkToProfile: Bool
    }

    private func postPage(
        @ViewBuilder imageContent: @escaping () -> some View,
        meta: PostPageMeta
    ) -> some View {
        GeometryReader { geo in
            ScrollView {
                VStack(alignment: .leading, spacing: AppStyle.Spacing.medium) {
                    imageContent()
                    postInfo(meta: meta)
                }
                .frame(minHeight: geo.size.height)
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Remote Image

    private func remoteImage(url: URL) -> some View {
        RemoteImage(url: url, contentMode: .fit)
            .overlay {
                if let icon = viewModel?.overlayIcon {
                    Image(systemName: icon)
                        .font(.system(size: 80))
                        .foregroundStyle(viewModel?.overlayColor ?? .clear)
                        .scaleEffect(viewModel?.overlayScale ?? 0)
                        .opacity(viewModel?.overlayOpacity ?? 0)
                        .animation(.easeOut(duration: 0.3), value: viewModel?.overlayScale)
                        .animation(.easeInOut(duration: 0.4), value: viewModel?.overlayOpacity)
                        .allowsHitTesting(false)
                }
            }
    }

    // MARK: - Local Image

    private func localImage(uiImage: UIImage) -> some View {
        Image(uiImage: uiImage)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity)
            .clipped()
    }

    // MARK: - Post Info

    private func postInfo(meta: PostPageMeta) -> some View {
        VStack(alignment: .leading, spacing: AppStyle.Spacing.small) {
            if let user = meta.user {
                if meta.linkToProfile {
                    NavigationLink(destination: FriendProfileView(user: user)) {
                        Text(user.displayName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(user.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                }
            }

            if let pinnedBy = meta.pinnedByUsername {
                Label("Pinned by @\(pinnedBy)", systemImage: "pin.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.orange)
            }

            badgeChips

            captionSection(caption: meta.caption)
            metadataSection(timestamp: meta.timestamp, locationName: meta.locationName)
        }
        .padding(.horizontal, AppStyle.Padding.screenHorizontal)
    }

    // MARK: - Action Bar

    private func actionBar(viewModel: PostDetailViewModel) -> some View {
        HStack(spacing: 0) {
            ForEach(PostAction.allCases, id: \.self) { action in
                actionButton(for: action, viewModel: viewModel)
            }
        }
        .background(Color(.systemBackground))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("PostActionBar_\(viewModel.post.id.uuidString)")
    }

    private func actionButton(for action: PostAction, viewModel: PostDetailViewModel) -> some View {
        Button {
            viewModel.performAction(action, momentsStore: momentsStore)
        } label: {
            VStack(spacing: AppStyle.Spacing.tight) {
                Image(systemName: viewModel.iconName(for: action))
                    .contentTransition(.identity)
                    .font(.title3)
                Text(viewModel.displayLabel(for: action))
                    .contentTransition(.identity)
                    .font(.caption2.weight(.medium))
            }
            .foregroundStyle(actionColor(for: action, viewModel: viewModel))
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppStyle.Spacing.row)
            .contentShape(Rectangle())
        }
        .animation(.none, value: viewModel.isActionActive(action))
        .buttonStyle(.plain)
        .accessibilityIdentifier(action.accessibilityId)
        .accessibilityLabel(viewModel.accessibilityLabel(for: action))
        .accessibilityHint(viewModel.accessibilityHint(for: action))
    }

    private func actionColor(for action: PostAction, viewModel: PostDetailViewModel) -> Color {
        switch action {
        case .like:
            viewModel.isLiked ? .red : .primary
        case .pinToProfile:
            viewModel.isPinned ? .orange : .primary
        default:
            .primary
        }
    }

    // MARK: - Pending Action Bar

    @ViewBuilder
    private func pendingActionBar(for post: PendingPost) -> some View {
        switch post.status {
        case .draft, .failed:
            Button {
                uploadManager.retryPost(post)
                dismiss()
            } label: {
                Label("Upload", systemImage: "arrow.up.circle.fill")
            }
            .buttonStyle(.appPrimary)
            .padding(.horizontal, AppStyle.Padding.screenHorizontal)
            .padding(.vertical, AppStyle.Spacing.small)

        case .queued:
            HStack(spacing: AppStyle.Spacing.small) {
                Image(systemName: "clock.fill")
                    .foregroundStyle(.secondary)
                Text("Queued for upload")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppStyle.Padding.cardInner)

        case .uploading:
            HStack(spacing: AppStyle.Spacing.small) {
                ProgressView()
                Text("Uploading\u{2026}")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppStyle.Padding.cardInner)
        }
    }

    // MARK: - Badge Chips

    @ViewBuilder private var badgeChips: some View {
        if let viewModel, !viewModel.badges.isEmpty {
            HStack(spacing: AppStyle.Spacing.small) {
                ForEach(viewModel.badges) { badge in
                    Label(badge.badgeName, systemImage: badge.displayIcon)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(badge.displayColor)
                        .padding(.horizontal, AppStyle.Padding.pillHorizontal)
                        .padding(.vertical, AppStyle.Spacing.tight)
                        .background(badge.displayColor.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: AppStyle.CornerRadius.badge))
                }
            }
        }
    }

    // MARK: - Caption

    @ViewBuilder
    private func captionSection(caption: String) -> some View {
        if !caption.isEmpty {
            Text(caption)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Metadata

    private func metadataSection(timestamp: Date, locationName: String) -> some View {
        VStack(alignment: .leading, spacing: AppStyle.Spacing.tight) {
            Label {
                Text(timestamp.formatted(
                    .dateTime.month(.abbreviated).day().year().hour().minute()
                ))
            } icon: {
                Image(systemName: "clock")
            }

            if !locationName.isEmpty {
                Label {
                    Text(locationName)
                } icon: {
                    Image(systemName: "mappin.and.ellipse")
                }
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @MainActor
    private func deleteCurrentPost() async {
        guard let post = currentUploadedPost else { return }
        guard let authUserId = authManager.userId else {
            mutationError = "You must be signed in to delete a post."
            return
        }
        guard post.user.id == authUserId else {
            mutationError = "You can only delete your own posts."
            return
        }

        isMutatingPost = true
        defer { isMutatingPost = false }

        do {
            try await postRepository.deletePost(id: post.id, imagePath: post.imagePath)
            cacheInvalidator.postDeleted(userId: post.user.id)
            dismiss()
        } catch {
            let errorText = String(describing: error).lowercased()
            if errorText.contains("app.supabase_url") {
                mutationError = "Delete is blocked by a backend configuration issue (missing app.supabase_url). " +
                    "Please contact support or update the database function configuration."
            } else {
                mutationError = "Failed to delete post. Please try again."
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        PostDetailView(
            posts: ImagePost.samplePosts(
                near: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                around: Date()
            ),
            initialIndex: 0,
            queryDate: Date()
        )
    }
    .environment(FriendsStore())
    .environment(MomentsStore())
    .environment(PostMutationStore())
    .environment(AuthManager())
    .environment(UploadManager())
    .environment(DefaultBadgeRepository())
}
