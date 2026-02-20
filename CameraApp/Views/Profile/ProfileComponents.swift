import NukeUI
import SwiftUI

// MARK: - Post Row (excludes geography column)

/// Decodes a post row without the `location` geography column, which PostGIS
/// returns as WKB hex. Uses the separate `latitude`/`longitude` columns instead.
struct PostRowWithoutLocation: Codable {
    let id: UUID
    let userId: UUID
    let imagePath: String
    let caption: String?
    let latitude: Double
    let longitude: Double
    let locationName: String?
    let scope: String
    let createdAt: String?

    /// Columns to select — excludes the `location` geography column.
    static let selectColumns =
        "id,user_id,image_path,caption,latitude,longitude,location_name,scope,created_at"

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case imagePath = "image_path"
        case caption, latitude, longitude
        case locationName = "location_name"
        case scope
        case createdAt = "created_at"
    }
}

// MARK: - Profile Header

/// Reusable profile header with avatar, name, username, and customisable stats row.
struct ProfileHeaderView<Stats: View>: View {
    let user: User
    @ViewBuilder let stats: () -> Stats

    var body: some View {
        HStack(spacing: 16) {
            AvatarView(user: user, size: 72)
                .shadow(color: user.gradientColors.first?.opacity(0.25) ?? .clear, radius: 8, y: 3)

            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.displayName)
                        .font(.title3.weight(.bold))

                    Text("@\(user.username)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                stats()
            }

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Stat Item

/// Single stat label (e.g. "12 Posts") used in the profile header.
struct ProfileStatItem: View {
    let value: Int
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Text("\(value)")
                .font(.subheadline.weight(.bold))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Bio

/// Profile bio text, capped to 2 lines.
struct ProfileBioView: View {
    let bio: String

    var body: some View {
        Text(bio)
            .font(.subheadline)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lineLimit(2)
    }
}

// MARK: - Grid Item

/// Unified type for the profile photo grid. Wraps either a server-side uploaded
/// post or a local pending post that is still in the upload queue.
enum ProfileGridItem: Identifiable {
    case uploaded(ImagePost)
    case pending(PendingPost, UIImage?)

    var id: UUID {
        switch self {
        case let .uploaded(post): post.id
        case let .pending(post, _): post.id
        }
    }
}

// MARK: - Photo Grid

/// Instagram-style photo grid with navigation to post detail.
/// Supports both uploaded posts (navigable) and pending posts (with status overlay).
struct ProfilePhotoGrid: View {
    let items: [ProfileGridItem]
    let uploadedPosts: [ImagePost]
    var onRetry: ((PendingPost) -> Void)?
    var onRemove: ((PendingPost) -> Void)?

    private let spacing: CGFloat = 2

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: spacing) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                gridItemView(item: item, globalIndex: index)
            }
        }
    }

    @ViewBuilder
    private func gridItemView(item: ProfileGridItem, globalIndex: Int) -> some View {
        switch item {
        case let .uploaded(post):
            NavigationLink(
                destination: PostDetailView(
                    posts: uploadedPosts,
                    initialIndex: uploadedPostIndex(for: post),
                    queryDate: Date()
                )
            ) {
                uploadedGridCell(for: post)
            }
            .buttonStyle(.plain)

        case let .pending(post, image):
            pendingGridCell(post: post, image: image)
        }
    }

    private func uploadedPostIndex(for post: ImagePost) -> Int {
        uploadedPosts.firstIndex(where: { $0.id == post.id }) ?? 0
    }

    private func uploadedGridCell(for post: ImagePost) -> some View {
        LazyImage(url: post.imageURL) { state in
            if let image = state.image {
                Color.clear
                    .overlay {
                        image
                            .resizable()
                            .scaledToFill()
                    }
                    .clipped()
            } else if state.error != nil {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .overlay {
                        Image(systemName: "photo.badge.exclamationmark")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
            } else {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .overlay { ProgressView() }
            }
        }
        .aspectRatio(1, contentMode: .fill)
        .clipped()
    }

    private func pendingGridCell(post: PendingPost, image: UIImage?) -> some View {
        ZStack {
            if let image {
                Color.clear
                    .overlay {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    }
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color(.systemGray5))
            }

            Color.black.opacity(0.3)

            pendingStatusOverlay(for: post)
        }
        .aspectRatio(1, contentMode: .fill)
        .clipped()
        .onTapGesture {
            if post.status == .failed {
                onRetry?(post)
            }
        }
    }

    @ViewBuilder
    private func pendingStatusOverlay(for post: PendingPost) -> some View {
        switch post.status {
        case .draft:
            Image(systemName: "square.and.arrow.down.fill")
                .font(.title3)
                .foregroundStyle(.white)
        case .queued:
            Image(systemName: "clock.fill")
                .font(.title3)
                .foregroundStyle(.white)
        case .uploading:
            ProgressView()
                .tint(.white)
        case .failed:
            VStack(spacing: 4) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.red)
                Text("Tap to retry")
                    .font(.caption2)
                    .foregroundStyle(.white)
            }
        }
    }
}

// MARK: - Posts Section

/// Wrapper that renders a divider, then a loading indicator, empty state, or
/// photo grid depending on the current state.
struct ProfilePostsSection<EmptyContent: View>: View {
    let isLoading: Bool
    let items: [ProfileGridItem]
    let uploadedPosts: [ImagePost]
    var onRetry: ((PendingPost) -> Void)?
    var onRemove: ((PendingPost) -> Void)?
    @ViewBuilder let emptyContent: () -> EmptyContent

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            if isLoading, items.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else if items.isEmpty {
                emptyContent()
            } else {
                ProfilePhotoGrid(
                    items: items,
                    uploadedPosts: uploadedPosts,
                    onRetry: onRetry,
                    onRemove: onRemove
                )
            }
        }
    }
}

// MARK: - Posts Empty State

/// Configurable empty-state placeholder for the posts section.
struct ProfilePostsEmptyState: View {
    let icon: String
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)

            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
