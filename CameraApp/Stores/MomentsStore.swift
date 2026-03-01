import CoreLocation
import Foundation
import Observation

@MainActor @Observable
class MomentsStore: TabRefreshable {
    var moments: [Moment] = []
    var nearbyPosts: [UUID: [ImagePost]] = [:]
    /// True only during the initial data load (before any moments are available).
    var isLoading = false
    /// True only during a user-initiated pull-to-refresh. Center overlays must not
    /// appear while this is true — the native pull spinner is the only indicator.
    var isRefreshing = false
    var lastRefreshError: String?
    var pendingMoment: Moment?
    var selectedTab: Int = 0
    var errorMessage: String?

    /// The authenticated user's UUID. Must be set before calling any methods.
    var currentUserId: UUID?

    /// Repository for data fetching (set from CameraAppApp on auth).
    var repository: (any MomentRepository)?

    /// Cache invalidator for notifying other layers of moment changes.
    var cacheInvalidator: CacheInvalidator?

    // MARK: - Load

    /// Fetches all moments with their nearby posts (initial load).
    func loadMoments() async {
        guard currentUserId != nil else { return }

        isLoading = true
        defer { isLoading = false }

        await fetchMomentsData()
    }

    /// Invalidates cached moments and reloads from the server-backed source.
    /// Guards against overlapping concurrent refresh operations.
    func refreshMoments() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        lastRefreshError = nil
        defer { isRefreshing = false }

        repository?.invalidate()
        await fetchMomentsData()
    }

    // MARK: - Shared Fetch

    private func fetchMomentsData() async {
        guard currentUserId != nil else { return }

        do {
            if let repo = repository {
                let (loadedMoments, loadedPosts) = try await repo.loadMomentsWithPosts()
                moments = loadedMoments
                nearbyPosts = loadedPosts
            } else {
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
            }
        } catch {
            let message = error.localizedDescription
            errorMessage = message
            lastRefreshError = message
        }
    }

    // MARK: - Delete

    /// Deletes a moment from Supabase and removes it from local state.
    func deleteMoment(_ moment: Moment) async {
        moments.removeAll { $0.id == moment.id }
        nearbyPosts.removeValue(forKey: moment.id)

        do {
            try await SupabaseManager.client.from("moments")
                .delete()
                .eq("id", value: moment.id)
                .execute()
            cacheInvalidator?.momentsChanged()
        } catch {
            errorMessage = error.localizedDescription
            await loadMoments()
        }
    }

    // MARK: - TabRefreshable

    var isInitialLoading: Bool {
        isLoading && moments.isEmpty
    }

    func refresh() async {
        await refreshMoments()
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

                cacheInvalidator?.momentsChanged()
                await loadMoments()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
