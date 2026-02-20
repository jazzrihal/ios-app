import CoreLocation
import NukeUI
import SwiftUI

// MARK: - Post Detail View

struct PostDetailView: View {
    @Environment(MomentsStore.self) private var store
    @Environment(AuthManager.self) private var authManager
    @Environment(UploadManager.self) private var uploadManager
    @Environment(\.dismiss) private var dismiss

    private let source: Source

    @State private var viewModel: PostDetailViewModel?

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
                                user: post.user,
                                caption: post.caption,
                                timestamp: post.timestamp,
                                locationName: post.locationName,
                                linkToProfile: true
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
                    user: authManager.currentProfile,
                    caption: post.caption ?? "",
                    timestamp: post.createdAt,
                    locationName: post.locationName ?? "",
                    linkToProfile: false
                )

                pendingActionBar(for: post)
            }
        }
        .background(Color(.systemBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: Binding(
            get: { viewModel?.showShareSheet ?? false },
            set: { viewModel?.showShareSheet = $0 }
        )) {
            if let viewModel {
                ShareSheet(items: [viewModel.post.imageURL])
            }
        }
        .onChange(of: viewModel?.shouldDismiss) { _, shouldDismiss in
            if shouldDismiss == true { dismiss() }
        }
        .onAppear {
            viewModel?.userId = authManager.userId
            viewModel?.loadLikesAndPins()
        }
    }

    // MARK: - Post Page

    private func postPage(
        @ViewBuilder imageContent: @escaping () -> some View,
        user: User?,
        caption: String,
        timestamp: Date,
        locationName: String,
        linkToProfile: Bool
    ) -> some View {
        GeometryReader { geo in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    imageContent()
                    postInfo(
                        user: user,
                        caption: caption,
                        timestamp: timestamp,
                        locationName: locationName,
                        linkToProfile: linkToProfile
                    )
                }
                .frame(minHeight: geo.size.height)
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Remote Image

    private func remoteImage(url: URL) -> some View {
        LazyImage(url: url) { state in
            if let image = state.image {
                image
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .clipped()
            } else if state.error != nil {
                ZStack {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 300)
                    VStack(spacing: 6) {
                        Image(systemName: "photo.badge.exclamationmark")
                            .font(.title2)
                        Text("Failed to load")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
            } else {
                ZStack {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 300)
                    ProgressView()
                }
            }
        }
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

    private func postInfo(
        user: User?,
        caption: String,
        timestamp: Date,
        locationName: String,
        linkToProfile: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let user {
                if linkToProfile {
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

            captionSection(caption: caption)
            metadataSection(timestamp: timestamp, locationName: locationName)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Action Bar

    private func actionBar(viewModel: PostDetailViewModel) -> some View {
        HStack(spacing: 0) {
            ForEach(PostAction.allCases, id: \.self) { action in
                actionButton(for: action, viewModel: viewModel)
            }
        }
        .background(Color(.systemBackground))
    }

    private func actionButton(for action: PostAction, viewModel: PostDetailViewModel) -> some View {
        Button {
            viewModel.performAction(action, store: store)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: viewModel.iconName(for: action))
                    .contentTransition(.identity)
                    .font(.title3)
                Text(viewModel.displayLabel(for: action))
                    .contentTransition(.identity)
                    .font(.caption2.weight(.medium))
            }
            .foregroundStyle(actionColor(for: action, viewModel: viewModel))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .animation(.none, value: viewModel.isActionActive(action))
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
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

        case .queued:
            HStack(spacing: 8) {
                Image(systemName: "clock.fill")
                    .foregroundStyle(.secondary)
                Text("Queued for upload")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)

        case .uploading:
            HStack(spacing: 8) {
                ProgressView()
                Text("Uploading\u{2026}")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
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
        VStack(alignment: .leading, spacing: 4) {
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
    .environment(AuthManager())
    .environment(UploadManager())
}
