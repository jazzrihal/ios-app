import CoreLocation
import Observation

@Observable
final class FriendsFeedViewModel {
    var posts: [ImagePost] = []
    var isLoading = false
    var isLoadingMore = false
    var hasMorePages = true
    var errorMessage: String?

    private let pageSize = 20

    /// Fetches the first page of posts from all provided friends (initial load or refresh).
    @MainActor
    func loadPosts(friends: [User]) async {
        let friendIds = friends.map(\.id)
        guard !friendIds.isEmpty else {
            posts = []
            hasMorePages = false
            return
        }

        isLoading = true
        errorMessage = nil
        hasMorePages = true

        let userLookup = Dictionary(uniqueKeysWithValues: friends.map { ($0.id, $0) })

        do {
            let rows: [PostRowWithoutLocation] = try await SupabaseManager.client
                .from("posts")
                .select(PostRowWithoutLocation.selectColumns)
                .in("user_id", values: friendIds)
                .order("created_at", ascending: false)
                .range(from: 0, to: pageSize - 1)
                .execute()
                .value

            posts = rows.compactMap { row in
                guard let user = userLookup[row.userId] else { return nil }
                return ImagePost(
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
            hasMorePages = rows.count == pageSize
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// Loads the next page and appends to posts.
    @MainActor
    func loadNextPage(friends: [User]) async {
        guard hasMorePages, !isLoadingMore else { return }
        let friendIds = friends.map(\.id)
        guard !friendIds.isEmpty else { return }

        isLoadingMore = true

        let userLookup = Dictionary(uniqueKeysWithValues: friends.map { ($0.id, $0) })
        let from = posts.count
        let to = from + pageSize - 1

        do {
            let rows: [PostRowWithoutLocation] = try await SupabaseManager.client
                .from("posts")
                .select(PostRowWithoutLocation.selectColumns)
                .in("user_id", values: friendIds)
                .order("created_at", ascending: false)
                .range(from: from, to: to)
                .execute()
                .value

            let newPosts = rows.compactMap { row -> ImagePost? in
                guard let user = userLookup[row.userId] else { return nil }
                return ImagePost(
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
            posts.append(contentsOf: newPosts)
            hasMorePages = rows.count == pageSize
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoadingMore = false
    }
}
