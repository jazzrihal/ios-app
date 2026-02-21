import Observation
import SwiftUI

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
    var isLoadingMore = false
    var hasMorePages = true
    var postsError: String?

    private let pageSize = 20

    var ownPostCount: Int {
        userPosts.filter(\.isOwnPost).count
    }

    /// Set to `true` when the view should dismiss (e.g. after removing a friend).
    var shouldDismiss = false

    // MARK: - Repositories

    var postRepository: (any PostRepository)?
    var profileRepository: (any ProfileRepository)?

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
                if let repo = profileRepository {
                    user = try await repo.loadProfile(userId: user.id)
                } else {
                    let profile: PublicSchema.ProfilesSelect = try await SupabaseManager.client
                        .from("profiles")
                        .select()
                        .eq("id", value: user.id)
                        .single()
                        .execute()
                        .value
                    user = User(from: profile)
                }
            } catch {
                print("[FriendProfile] Failed to load full profile: \(error)")
            }
        }
    }

    // MARK: - Posts Loading

    /// Fetches the first page of the user's posts and pinned posts. RLS handles scope filtering.
    @MainActor
    func loadPosts() async {
        isLoadingPosts = true
        postsError = nil
        hasMorePages = true

        do {
            if let repo = postRepository {
                userPosts = try await repo.userPostsAndPins(
                    userId: user.id, pageSize: pageSize, pageOffset: 0
                )
            } else {
                let params = GetUserPostsAndPinsParams(
                    targetUserId: user.id, pageSize: pageSize, pageOffset: 0
                )
                let rows: [UserPostWithPinRow] = try await SupabaseManager.client
                    .rpc("get_user_posts_and_pins", params: params)
                    .execute()
                    .value

                userPosts = rows.map { row in
                    var post = ImagePost(from: row)
                    if row.isPinnedByUser {
                        post.pinnedByUsername = user.username
                    }
                    return post
                }
            }
            hasMorePages = userPosts.count == pageSize
        } catch {
            postsError = error.localizedDescription
        }

        isLoadingPosts = false
    }

    /// Appends the next page of posts.
    @MainActor
    func loadMorePosts() async {
        guard hasMorePages, !isLoadingMore else { return }
        isLoadingMore = true

        do {
            let newPosts: [ImagePost]
            if let repo = postRepository {
                newPosts = try await repo.userPostsAndPins(
                    userId: user.id, pageSize: pageSize, pageOffset: userPosts.count
                )
            } else {
                let params = GetUserPostsAndPinsParams(
                    targetUserId: user.id, pageSize: pageSize, pageOffset: userPosts.count
                )
                let rows: [UserPostWithPinRow] = try await SupabaseManager.client
                    .rpc("get_user_posts_and_pins", params: params)
                    .execute()
                    .value

                newPosts = rows.map { row in
                    var post = ImagePost(from: row)
                    if row.isPinnedByUser {
                        post.pinnedByUsername = user.username
                    }
                    return post
                }
            }
            userPosts.append(contentsOf: newPosts)
            hasMorePages = newPosts.count == pageSize
        } catch {
            postsError = error.localizedDescription
        }

        isLoadingMore = false
    }

    /// Resets and reloads from the first page (for pull-to-refresh).
    @MainActor
    func refreshPosts() async {
        await loadPosts()
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
