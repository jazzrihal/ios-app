import CoreLocation
import Observation
import SwiftUI

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

// MARK: - Friend Profile View Model

@Observable
final class FriendProfileViewModel {
    // MARK: - Input

    /// The displayed user. Initially set from the navigation source (which may
    /// have incomplete data, e.g. from NearbyPostRow), then refreshed with the
    /// full profile from the `profiles` table.
    private(set) var user: User

    // MARK: - State

    var showRemoveConfirmation = false
    var userPosts: [ImagePost] = []
    var isLoadingPosts = false
    var postsError: String?

    /// Set to `true` when the view should dismiss (e.g. after removing a friend).
    var shouldDismiss = false

    // MARK: - Init

    init(user: User) {
        self.user = user
    }

    // MARK: - Profile Loading

    /// Fetches the full profile from the `profiles` table so that bio,
    /// friend_count, post_count, etc. are accurate regardless of the
    /// navigation source (FriendsView vs ExploreView PostCard).
    func loadFullProfile() {
        Task { @MainActor in
            do {
                let profile: PublicSchema.ProfilesSelect = try await SupabaseManager.client
                    .from("profiles")
                    .select()
                    .eq("id", value: user.id)
                    .single()
                    .execute()
                    .value

                user = User(from: profile)
            } catch {
                // Keep the original user data as fallback
                print("[FriendProfile] Failed to load full profile: \(error)")
            }
        }
    }

    // MARK: - Posts Loading

    /// Columns to select — excludes the `location` geography column which
    /// PostGIS returns as WKB hex (incompatible with GeographySelect).
    /// The backend provides `latitude` / `longitude` as separate columns.
    private static let postColumns =
        "id,user_id,image_path,caption,latitude,longitude,location_name,scope,created_at"

    /// Fetches the user's posts from Supabase. RLS handles scope filtering.
    func loadPosts() {
        isLoadingPosts = true
        postsError = nil

        Task { @MainActor in
            do {
                let rows: [PostRowWithoutLocation] = try await SupabaseManager.client
                    .from("posts")
                    .select(Self.postColumns)
                    .eq("user_id", value: user.id)
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
                postsError = error.localizedDescription
            }

            isLoadingPosts = false
        }
    }

    func sendRequest(store: FriendsStore) {
        withAnimation(.spring(duration: 0.3)) {
            store.sendRequest(to: user)
        }
    }

    func cancelRequest(store: FriendsStore) {
        withAnimation(.spring(duration: 0.3)) {
            store.cancelRequest(to: user)
        }
    }

    func acceptRequest(store: FriendsStore) {
        withAnimation(.spring(duration: 0.3)) {
            store.acceptRequest(from: user)
        }
    }

    func declineRequest(store: FriendsStore) {
        withAnimation(.spring(duration: 0.3)) {
            store.declineRequest(from: user)
        }
        shouldDismiss = true
    }

    func removeFriend(store: FriendsStore) {
        withAnimation(.spring(duration: 0.3)) {
            store.removeFriend(user)
        }
        shouldDismiss = true
    }
}
