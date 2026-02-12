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

// MARK: - Photo Grid

/// Instagram-style photo grid with navigation to post detail.
/// Rows with fewer than `columnCount` items expand to fill the full width,
/// keeping every cell square.
struct ProfilePhotoGrid: View {
    let posts: [ImagePost]

    private let columnCount = 3
    private let spacing: CGFloat = 2

    /// Posts split into rows of `columnCount`, preserving original indices.
    private var rows: [[(offset: Int, element: ImagePost)]] {
        let enumerated = Array(posts.enumerated())
        return stride(from: 0, to: enumerated.count, by: columnCount).map {
            Array(enumerated[$0 ..< min($0 + columnCount, enumerated.count)])
        }
    }

    var body: some View {
        VStack(spacing: spacing) {
            ForEach(rows.indices, id: \.self) { rowIndex in
                HStack(spacing: spacing) {
                    ForEach(rows[rowIndex], id: \.element.id) { item in
                        NavigationLink(
                            destination: PostDetailView(
                                posts: posts,
                                initialIndex: item.offset,
                                queryDate: Date()
                            )
                        ) {
                            gridCell(for: item.element)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func gridCell(for post: ImagePost) -> some View {
        AsyncImage(url: post.imageURL) { phase in
            switch phase {
            case .empty:
                Rectangle()
                    .fill(Color(.systemGray5))
                    .overlay { ProgressView() }
            case let .success(image):
                Color.clear
                    .overlay {
                        image
                            .resizable()
                            .scaledToFill()
                    }
                    .clipped()
            case .failure:
                Rectangle()
                    .fill(Color(.systemGray5))
                    .overlay {
                        Image(systemName: "photo.badge.exclamationmark")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
            @unknown default:
                EmptyView()
            }
        }
        .aspectRatio(1, contentMode: .fill)
        .clipped()
    }
}

// MARK: - Posts Section

/// Wrapper that renders a divider, then a loading indicator, empty state, or
/// photo grid depending on the current state.
struct ProfilePostsSection<EmptyContent: View>: View {
    let isLoading: Bool
    let posts: [ImagePost]
    @ViewBuilder let emptyContent: () -> EmptyContent

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else if posts.isEmpty {
                emptyContent()
            } else {
                ProfilePhotoGrid(posts: posts)
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
