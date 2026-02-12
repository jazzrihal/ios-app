import CoreLocation
import SwiftUI

struct ProfileView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(FriendsStore.self) private var friendsStore

    @State private var userPosts: [ImagePost] = []
    @State private var isLoadingPosts = false

    private let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)

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
                        Task { await authManager.signOut() }
                    } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .task { await loadPosts() }
        }
    }

    // MARK: - Content

    private func profileContent(user: User) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                profileHeader(user: user)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                if !user.bio.isEmpty {
                    bioSection(user: user)
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                }

                postsSection
                    .padding(.top, 16)
            }
        }
    }

    // MARK: - Data Loading

    /// Columns to select — excludes the `location` geography column.
    private static let postColumns =
        "id,user_id,image_path,caption,latitude,longitude,location_name,scope,created_at"

    /// Loads the current user's posts from the `posts` table.
    private func loadPosts() async {
        guard let userId = authManager.userId,
              let user = authManager.currentProfile else { return }
        isLoadingPosts = true
        do {
            let rows: [PostRowWithoutLocation] = try await SupabaseManager.client
                .from("posts")
                .select(Self.postColumns)
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

    // MARK: - Profile Header (compact horizontal)

    private func profileHeader(user: User) -> some View {
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

                HStack(spacing: 16) {
                    statItem(value: userPosts.count, label: "Posts")
                    statItem(value: friendsStore.friends.count, label: "Friends")
                }
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - Stats

    private func statItem(value: Int, label: String) -> some View {
        HStack(spacing: 4) {
            Text("\(value)")
                .font(.subheadline.weight(.bold))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Bio

    private func bioSection(user: User) -> some View {
        Text(user.bio)
            .font(.subheadline)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lineLimit(2)
    }

    // MARK: - Posts

    private var postsSection: some View {
        VStack(spacing: 0) {
            Divider()

            if isLoadingPosts {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else if userPosts.isEmpty {
                postsEmptyState
            } else {
                postsGrid
            }
        }
    }

    private var postsGrid: some View {
        LazyVGrid(columns: gridColumns, spacing: 2) {
            ForEach(Array(userPosts.enumerated()), id: \.element.id) { index, post in
                NavigationLink(destination: PostDetailView(posts: userPosts, initialIndex: index, queryDate: Date())) {
                    AsyncImage(url: post.imageURL) { phase in
                        switch phase {
                        case .empty:
                            Rectangle()
                                .fill(Color(.systemGray5))
                                .overlay { ProgressView() }
                        case let .success(image):
                            image
                                .resizable()
                                .scaledToFill()
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
                .buttonStyle(.plain)
            }
        }
    }

    private var postsEmptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "camera")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)

            Text("No photos yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Your photos will appear here.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Post Row (excludes geography column)

/// Decodes a post row without the `location` geography column, which PostGIS
/// returns as WKB hex. Uses the separate `latitude`/`longitude` columns instead.
private struct PostRowWithoutLocation: Codable {
    let id: UUID
    let userId: UUID
    let imagePath: String
    let caption: String?
    let latitude: Double
    let longitude: Double
    let locationName: String?
    let scope: String
    let createdAt: String?

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

// MARK: - Preview

#Preview {
    ProfileView()
        .environment(AuthManager())
        .environment(FriendsStore())
        .environment(MomentsStore())
}
