import CoreLocation
import Foundation
import Observation

@MainActor @Observable
class MomentsStore {
    var moments: [Moment] = []
    var nearbyPosts: [UUID: [ImagePost]] = [:]
    var isLoading = false
    var pendingMoment: Moment?
    var selectedTab: Int = 0
    var errorMessage: String?

    /// The authenticated user's UUID. Must be set before calling any methods.
    var currentUserId: UUID?

    // MARK: - Load

    /// Fetches all moments with their nearby posts via the `moments_with_nearby_posts` RPC.
    func loadMoments() async {
        guard currentUserId != nil else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let params = MomentsWithNearbyPostsParams(
                radiusMeters: nil,
                dateRangeDays: nil,
                timeDecayHours: nil,
                distanceWeight: nil,
                postsPerMoment: 5
            )

            let rows: [MomentWithNearbyPostsRow] = try await SupabaseManager.client
                .rpc("moments_with_nearby_posts", params: params)
                .execute()
                .value

            nearbyPosts = Dictionary(
                uniqueKeysWithValues: rows.map { row in
                    (row.momentId, row.nearbyPosts.map { ImagePost(from: $0) })
                }
            )
            moments = rows.map { Moment(from: $0) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Delete

    /// Deletes a moment from Supabase and removes it from local state.
    func deleteMoment(_ moment: Moment) async {
        // Optimistic local removal
        moments.removeAll { $0.id == moment.id }
        nearbyPosts.removeValue(forKey: moment.id)

        do {
            try await SupabaseManager.client.from("moments")
                .delete()
                .eq("id", value: moment.id)
                .execute()
        } catch {
            errorMessage = error.localizedDescription
            // Reload to restore consistent state on failure
            await loadMoments()
        }
    }

    // MARK: - Add

    func addMoment(date: Date, locationName: String, coordinate: CLLocationCoordinate2D) {
        guard let userId = currentUserId else { return }

        isLoading = true

        Task {
            defer { isLoading = false }

            do {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

                let insert = PublicSchema.MomentsInsert(
                    createdAt: nil,
                    id: UUID(),
                    latitude: coordinate.latitude,
                    location: nil,
                    locationName: locationName,
                    longitude: coordinate.longitude,
                    momentDate: formatter.string(from: date),
                    userId: userId
                )
                try await SupabaseManager.client.from("moments").insert(insert).execute()

                await loadMoments()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
