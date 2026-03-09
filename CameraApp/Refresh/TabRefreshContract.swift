import SwiftUI

// MARK: - Tab Refresh Contract

//
// Standard interface for top-level tab refresh surfaces.
//
// Formal conformers: MomentsStore, ExploreViewModel, FriendsFeedViewModel.
//
// Pattern followers (same state model; cannot formally conform due to API shape):
//   - ProfileView:          isRefreshing/@State lives on the View struct, not a separate type.
//
// All implementing types must:
//   - Distinguish initial-load state (isInitialLoading) from manual pull-refresh (isRefreshing).
//   - Guard against overlapping manual refresh operations.
//   - Not show full-screen/center overlay spinners while isRefreshing is true — native pull
//     spinner is the only visible indicator during a manual refresh.
//   - Propagate pull refresh to the active sub-surface content per the map below.
//
// Sub-Surface Refresh Map
// =======================
//
// Explore (ExploreView / ExploreViewModel):
//   pull → refreshSearch()
//     → invalidates nearby-post cache + re-runs current search query at current pin/date.
//   Sub-surfaces: single search surface; no conditional dispatch needed.
//
// Moments (MomentsView / MomentsStore):
//   pull → refreshMoments()
//     → invalidates moments cache + reloads all moments with nearby posts.
//   Sub-surfaces: single list surface; no conditional dispatch needed.
//
// Friends (FriendsView):
//   pull → section-specific refresh (dispatched by the active FriendsSection):
//     .feed section       → FriendsFeedViewModel.refreshPosts()   (invalidates feed cache)
//     .friends section    → FriendsStore.refreshAll()             (reloads friends + requests)
//     .addFriend section  → FriendsStore.refreshAll() + re-runs current search query
//   Sub-surfaces: each tab owns and triggers its own refresh independently.
//
// Profile (ProfileView):
//   pull → invalidates user-post cache + reloads current user's post grid.
//   Sub-surfaces: single grid surface; no conditional dispatch needed.

protocol TabRefreshable {
    /// True only while the first data load is in-flight (before any data is available).
    var isInitialLoading: Bool { get }

    /// True only while a user-initiated pull-to-refresh is in-flight.
    var isRefreshing: Bool { get }

    /// The most recent refresh error, if any.
    var lastRefreshError: String? { get }

    /// Performs a manual refresh: invalidates caches and reloads from the server.
    /// Implementations must guard against overlapping calls.
    func refresh() async
}

// MARK: - Standard View Modifiers

extension View {
    /// Wires `.refreshable` using the standard tab refresh contract.
    ///
    /// Prefer ``tabLoadable(isLoading:isRefreshing:onRefresh:)`` for tab surfaces — it
    /// bundles the loading overlay with refresh wiring. Use this lighter variant only for
    /// non-tab views that need pull-to-refresh without a loading overlay.
    func tabRefreshable(_ action: @escaping () async -> Void) -> some View {
        refreshable { await Self.detachedRefresh(action) }
    }

    /// Combines a centered loading spinner with pull-to-refresh for tab surfaces.
    ///
    /// - The spinner is shown only while `isLoading` is true **and** `isRefreshing` is
    ///   false, so the native pull indicator remains the sole loading signal during a
    ///   manual refresh.
    /// - Each tab supplies its own loading state and refresh callback.
    func tabLoadable(
        isLoading: Bool,
        isRefreshing: Bool = false,
        onRefresh: @escaping () async -> Void
    ) -> some View {
        refreshable {
            await Self.detachedRefresh(onRefresh)
        }
        .overlay {
            if isLoading, !isRefreshing {
                ProgressView()
                    .tint(.secondary)
            }
        }
    }

    /// Runs the refresh callback in an unstructured `Task` so that SwiftUI's
    /// cancellation of the `.refreshable` task (triggered by `@Observable`
    /// state changes re-evaluating the view body) cannot kill in-flight
    /// network requests. The `.refreshable` indicator still waits for the
    /// work to finish via `task.value`.
    private static func detachedRefresh(
        _ action: @escaping () async -> Void
    ) async {
        await Task { @MainActor in
            await action()
        }.value
    }
}
