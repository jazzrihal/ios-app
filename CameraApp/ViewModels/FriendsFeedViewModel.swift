import CoreLocation
import Observation

@Observable
final class FriendsFeedViewModel {
    var posts: [ImagePost] = []
    var isLoading = false
    var errorMessage: String?

    /// Fetches recent posts from all provided friends.
    func loadPosts(friends: [User]) {
        let friendIds = friends.map(\.id)
        guard !friendIds.isEmpty else {
            posts = []
            return
        }

        isLoading = true
        errorMessage = nil

        let userLookup = Dictionary(uniqueKeysWithValues: friends.map { ($0.id, $0) })

        Task { @MainActor in
            do {
                let rows: [PostRowWithoutLocation] = try await SupabaseManager.client
                    .from("posts")
                    .select(PostRowWithoutLocation.selectColumns)
                    .in("user_id", values: friendIds)
                    .order("created_at", ascending: false)
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
            } catch {
                errorMessage = error.localizedDescription
            }

            isLoading = false
        }
    }
}
