import CoreLocation
import NukeUI
import SwiftUI

// MARK: - Post Detail View

struct PostDetailView: View {
    @Environment(MomentsStore.self) private var store
    @Environment(AuthManager.self) private var authManager
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: PostDetailViewModel

    init(posts: [ImagePost], initialIndex: Int, queryDate: Date) {
        _viewModel = State(initialValue: PostDetailViewModel(
            posts: posts,
            initialIndex: initialIndex,
            queryDate: queryDate
        ))
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $viewModel.currentIndex) {
                ForEach(Array(viewModel.posts.enumerated()), id: \.element.id) { index, post in
                    postPage(for: post)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            actionBar
        }
        .background(Color(.systemBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $viewModel.showShareSheet) {
            ShareSheet(items: [viewModel.post.imageURL])
        }
        .onChange(of: viewModel.shouldDismiss) { _, shouldDismiss in
            if shouldDismiss { dismiss() }
        }
        .onAppear {
            viewModel.userId = authManager.userId
            viewModel.loadLikesAndPins()
        }
    }

    // MARK: - Post Page

    private func postPage(for post: ImagePost) -> some View {
        GeometryReader { geo in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    postImage(for: post)
                    postInfo(for: post)
                }
                .frame(minHeight: geo.size.height)
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Post Image

    private func postImage(for post: ImagePost) -> some View {
        LazyImage(url: post.imageURL) { state in
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
            if let icon = viewModel.overlayIcon {
                Image(systemName: icon)
                    .font(.system(size: 80))
                    .foregroundStyle(viewModel.overlayColor)
                    .scaleEffect(viewModel.overlayScale)
                    .opacity(viewModel.overlayOpacity)
                    .animation(.easeOut(duration: 0.3), value: viewModel.overlayScale)
                    .animation(.easeInOut(duration: 0.4), value: viewModel.overlayOpacity)
                    .allowsHitTesting(false)
            }
        }
    }

    // MARK: - Post Info

    private func postInfo(for post: ImagePost) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            NavigationLink(destination: FriendProfileView(user: post.user)) {
                Text(post.user.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)

            captionSection(for: post)
            metadataSection(for: post)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack(spacing: 0) {
            ForEach(PostAction.allCases, id: \.self) { action in
                actionButton(for: action)
            }
        }
        .background(Color(.systemBackground))
    }

    private func actionButton(for action: PostAction) -> some View {
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
            .foregroundStyle(actionColor(for: action))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .animation(.none, value: viewModel.isActionActive(action))
        .accessibilityLabel(viewModel.accessibilityLabel(for: action))
        .accessibilityHint(viewModel.accessibilityHint(for: action))
    }

    private func actionColor(for action: PostAction) -> Color {
        switch action {
        case .like:
            viewModel.isLiked ? .red : .primary
        case .pinToProfile:
            viewModel.isPinned ? .orange : .primary
        default:
            .primary
        }
    }

    // MARK: - Caption

    @ViewBuilder
    private func captionSection(for post: ImagePost) -> some View {
        if !post.caption.isEmpty {
            Text(post.caption)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Metadata

    private func metadataSection(for post: ImagePost) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label {
                Text(post.timestamp.formatted(
                    .dateTime.month(.abbreviated).day().year().hour().minute()
                ))
            } icon: {
                Image(systemName: "clock")
            }

            if !post.locationName.isEmpty {
                Label {
                    Text(post.locationName)
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
}
