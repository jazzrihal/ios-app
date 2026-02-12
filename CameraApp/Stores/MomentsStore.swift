import CoreLocation
import Foundation
import Observation

@Observable
class MomentsStore {
    var moments: [Moment] = []
    var pendingMoment: Moment?
    var selectedTab: Int = 0
    var errorMessage: String?

    /// The authenticated user's UUID. Must be set before calling any methods.
    var currentUserId: UUID?

    // MARK: - Load

    /// Fetches all moments for the current user from the `moments` table.
    func loadMoments() async {
        guard let userId = currentUserId else { return }

        do {
            let rows: [PublicSchema.MomentsSelect] = try await SupabaseManager.client
                .from("moments")
                .select()
                .eq("user_id", value: userId)
                .order("created_at", ascending: false)
                .execute()
                .value

            moments = rows.map { Moment(from: $0) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Add

    func addMoment(date: Date, locationName: String, coordinate: CLLocationCoordinate2D) {
        guard let userId = currentUserId else { return }

        let moment = Moment(
            date: date,
            locationName: locationName,
            coordinate: coordinate,
            addedAt: Date()
        )

        // Optimistic insert
        moments.insert(moment, at: 0)

        Task {
            do {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

                let insert = PublicSchema.MomentsInsert(
                    createdAt: nil,
                    id: moment.id,
                    latitude: coordinate.latitude,
                    location: nil,
                    locationName: locationName,
                    longitude: coordinate.longitude,
                    momentDate: formatter.string(from: date),
                    userId: userId
                )
                try await SupabaseManager.client.from("moments").insert(insert).execute()
            } catch {
                // Revert on failure
                moments.removeAll { $0.id == moment.id }
                errorMessage = error.localizedDescription
            }
        }
    }
}
