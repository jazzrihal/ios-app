import Foundation
import Observation

@Observable
final class FriendsFeedViewModel: TabRefreshable {
    var posts: [ImagePost] = []
    /// True only while the first page load is in-flight (before any posts are available).
    var isLoading = false
    /// True only during a user-initiated pull-to-refresh. Center overlays must not
    /// appear while this is true — the native pull spinner is the only indicator.
    var isRefreshing = false
    var isLoadingMore = false
    var hasMorePages = true
    var errorMessage: String?

    var isInitialLoading: Bool {
        isLoading && posts.isEmpty
    }

    private let pageSize = 20
    private let duplicateLoadWindow: TimeInterval = 0.75
    private var lastFirstPageLoadToken: String?
    private var lastFirstPageLoadAt: Date?
    private var latestRefreshContextFriends: [User] = []

    var postRepository: (any PostRepository)?
    var lastRefreshError: String? {
        errorMessage
    }

    /// Fetches the first page of posts from all provided friends (initial load or refresh).
    @MainActor
    func loadPosts(friends: [User], force: Bool = false) async {
        let friendIds = friends.map(\.id)
        let loadToken = makeLoadToken(friendIds: friendIds)

        if shouldSkipDuplicateFirstPageLoad(token: loadToken, force: force) {
            return
        }

        guard !friendIds.isEmpty else {
            posts = []
            hasMorePages = false
            recordFirstPageLoad(token: loadToken)
            return
        }

        isLoading = true
        errorMessage = nil
        hasMorePages = true

        do {
            if let repo = postRepository {
                posts = try await repo.friendFeedPosts(
                    friendIds: friendIds, friends: friends, pageSize: pageSize, from: 0
                )
            } else {
                let userLookup = Dictionary(uniqueKeysWithValues: friends.map { ($0.id, $0) })
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
                    return ImagePost(from: row, user: user)
                }
            }
            hasMorePages = posts.count == pageSize
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
        recordFirstPageLoad(token: loadToken)
    }

    /// Invalidates feed cache and reloads first page from a network-fresh source.
    /// Guards against overlapping concurrent refresh operations.
    @MainActor
    func refreshPosts(friends: [User]) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        postRepository?.invalidateFriendFeed()
        await loadPosts(friends: friends, force: true)
    }

    /// Stores the latest friend set so `refresh()` can satisfy `TabRefreshable`.
    @MainActor
    func setRefreshContext(friends: [User]) {
        latestRefreshContextFriends = friends
    }

    func refresh() async {
        await refreshPosts(friends: latestRefreshContextFriends)
    }

    /// Loads the next page and appends to posts.
    @MainActor
    func loadNextPage(friends: [User]) async {
        guard hasMorePages, !isLoadingMore, !isRefreshing else { return }
        let friendIds = friends.map(\.id)
        guard !friendIds.isEmpty else { return }

        isLoadingMore = true

        do {
            let newPosts: [ImagePost]
            if let repo = postRepository {
                newPosts = try await repo.friendFeedPosts(
                    friendIds: friendIds, friends: friends, pageSize: pageSize, from: posts.count
                )
            } else {
                let userLookup = Dictionary(uniqueKeysWithValues: friends.map { ($0.id, $0) })
                let from = posts.count
                let to = from + pageSize - 1
                let rows: [PostRowWithoutLocation] = try await SupabaseManager.client
                    .from("posts")
                    .select(PostRowWithoutLocation.selectColumns)
                    .in("user_id", values: friendIds)
                    .order("created_at", ascending: false)
                    .range(from: from, to: to)
                    .execute()
                    .value

                newPosts = rows.compactMap { row -> ImagePost? in
                    guard let user = userLookup[row.userId] else { return nil }
                    return ImagePost(from: row, user: user)
                }
            }
            posts.append(contentsOf: newPosts)
            hasMorePages = newPosts.count == pageSize
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoadingMore = false
    }

    private func makeLoadToken(friendIds: [UUID]) -> String {
        friendIds
            .map(\.uuidString)
            .sorted()
            .joined(separator: ",")
    }

    private func shouldSkipDuplicateFirstPageLoad(token: String, force: Bool) -> Bool {
        guard !force else { return false }
        guard !token.isEmpty else { return false }
        guard lastFirstPageLoadToken == token, let loadedAt = lastFirstPageLoadAt else { return false }
        return Date().timeIntervalSince(loadedAt) < duplicateLoadWindow
    }

    private func recordFirstPageLoad(token: String) {
        lastFirstPageLoadToken = token
        lastFirstPageLoadAt = Date()
    }
}
