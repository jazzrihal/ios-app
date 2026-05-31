import Foundation
import Observation

/// Centralized cache invalidation hub. Mutations (uploads, likes, pins,
/// friend changes) call methods here, and repositories observe the
/// invalidation timestamps to know when to discard stale entries.
@MainActor @Observable
final class CacheInvalidator {
    private(set) var postRepository: (any PostRepository)?
    private(set) var friendRepository: (any FriendRepository)?
    private(set) var momentRepository: (any MomentRepository)?
    private(set) var profileRepository: (any ProfileRepository)?

    func configure(
        posts: any PostRepository,
        friends: any FriendRepository,
        moments: any MomentRepository,
        profiles: any ProfileRepository
    ) {
        postRepository = posts
        friendRepository = friends
        momentRepository = moments
        profileRepository = profiles
    }

    /// Call after a new post is uploaded successfully.
    func postUploaded(userId: UUID) {
        postRepository?.invalidateUserPosts(userId)
        postRepository?.invalidateNearbyPosts()
    }

    /// Call after a like or pin toggle so cached viewer state is refreshed on next load.
    func postMutated(postId: UUID, userId: UUID) {
        postRepository?.invalidateUserPosts(userId)
        postRepository?.invalidateFriendFeed()
    }

    /// Call after a post caption/scope edit so all post surfaces refresh.
    func postEdited(userId: UUID) {
        postRepository?.invalidateUserPosts(userId)
        postRepository?.invalidateFriendFeed()
        postRepository?.invalidateNearbyPosts()
    }

    /// Call after deleting a post so all post surfaces refresh.
    func postDeleted(userId: UUID) {
        postRepository?.invalidateUserPosts(userId)
        postRepository?.invalidateFriendFeed()
        postRepository?.invalidateNearbyPosts()
    }

    /// Call after any friend status change (send/accept/decline/remove).
    func friendshipChanged(userId: UUID) {
        friendRepository?.invalidate(userId: userId)
        postRepository?.invalidateFriendFeed()
    }

    /// Call after a moment is added or deleted.
    func momentsChanged() {
        momentRepository?.invalidate()
    }

    /// Call after a profile is updated.
    func profileChanged(userId: UUID) {
        profileRepository?.invalidate(userId: userId)
    }

    /// Clear every locally cached model when the authenticated session changes.
    func clearAllCachedData() {
        (postRepository as? DefaultPostRepository)?.purgeAllCachedData()
        (friendRepository as? DefaultFriendRepository)?.purgeAllCachedData()
        (momentRepository as? DefaultMomentRepository)?.purgeAllCachedData()
        (profileRepository as? DefaultProfileRepository)?.purgeAllCachedData()
    }
}
