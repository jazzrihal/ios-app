import Foundation
import Observation
import SwiftUI

@Observable
class PostMutationStore {
    var pinnedPostIDs: Set<UUID> = []
    var likedPostIDs: Set<UUID> = []

    /// The authenticated user's UUID. Must be set before calling any methods.
    var currentUserId: UUID?

    /// Cache invalidator for notifying the cache layer of like/pin changes.
    var cacheInvalidator: CacheInvalidator?

    // MARK: - Query

    func isPinned(_ postId: UUID) -> Bool {
        pinnedPostIDs.contains(postId)
    }

    func isLiked(_ postId: UUID) -> Bool {
        likedPostIDs.contains(postId)
    }

    // MARK: - Bulk Load

    /// Fetches the current user's likes and pins for a set of post IDs and
    /// merges them into the local sets.
    func loadPinsAndLikes(for postIds: [UUID]) async {
        guard let userId = currentUserId, !postIds.isEmpty else { return }

        do {
            let likes: [PublicSchema.LikesSelect] = try await SupabaseManager.client
                .from("likes")
                .select()
                .eq("user_id", value: userId)
                .in("post_id", values: postIds)
                .execute()
                .value

            let fetchedLikeIDs = Set(likes.map(\.postId))
            likedPostIDs.formUnion(fetchedLikeIDs)
            likedPostIDs.subtract(Set(postIds).subtracting(fetchedLikeIDs))
        } catch {
            print("[PostMutationStore] Failed to load likes: \(error)")
        }

        do {
            let pins: [PublicSchema.PinsSelect] = try await SupabaseManager.client
                .from("pins")
                .select()
                .eq("user_id", value: userId)
                .in("post_id", values: postIds)
                .execute()
                .value

            let fetchedPinIDs = Set(pins.map(\.postId))
            pinnedPostIDs.formUnion(fetchedPinIDs)
            pinnedPostIDs.subtract(Set(postIds).subtracting(fetchedPinIDs))
        } catch {
            print("[PostMutationStore] Failed to load pins: \(error)")
        }
    }

    /// Seeds like and pin state from already-fetched posts whose `hasViewerState` is true.
    /// Avoids extra network round-trips when the RPC response includes viewer fields.
    func seedFromPosts(_ posts: [ImagePost]) {
        for post in posts {
            if post.isLikedByViewer {
                likedPostIDs.insert(post.id)
            } else {
                likedPostIDs.remove(post.id)
            }
            if post.isPinnedByViewer {
                pinnedPostIDs.insert(post.id)
            } else {
                pinnedPostIDs.remove(post.id)
            }
        }
    }

    // MARK: - Toggle Pin

    func togglePin(_ postId: UUID, overlayCallback: ((String, Color) -> Void)? = nil) {
        guard let userId = currentUserId else { return }

        if isPinned(postId) {
            pinnedPostIDs.remove(postId)
            Task {
                do {
                    try await SupabaseManager.client.from("pins")
                        .delete()
                        .eq("user_id", value: userId)
                        .eq("post_id", value: postId)
                        .execute()
                    await cacheInvalidator?.postMutated(postId: postId, userId: userId)
                } catch {
                    pinnedPostIDs.insert(postId)
                    print("[PostMutationStore] Unpin failed: \(error)")
                }
            }
        } else {
            pinnedPostIDs.insert(postId)
            overlayCallback?("pin.fill", .orange)
            Task {
                do {
                    let insert = PublicSchema.PinsInsert(
                        createdAt: nil, postId: postId, userId: userId
                    )
                    try await SupabaseManager.client.from("pins")
                        .insert(insert)
                        .execute()
                    await cacheInvalidator?.postMutated(postId: postId, userId: userId)
                } catch {
                    pinnedPostIDs.remove(postId)
                    print("[PostMutationStore] Pin failed: \(error)")
                }
            }
        }
    }

    // MARK: - Toggle Like

    func toggleLike(_ postId: UUID, overlayCallback: ((String, Color) -> Void)? = nil) {
        guard let userId = currentUserId else { return }

        if isLiked(postId) {
            likedPostIDs.remove(postId)
            Task {
                do {
                    try await SupabaseManager.client.from("likes")
                        .delete()
                        .eq("user_id", value: userId)
                        .eq("post_id", value: postId)
                        .execute()
                    await cacheInvalidator?.postMutated(postId: postId, userId: userId)
                } catch {
                    likedPostIDs.insert(postId)
                    print("[PostMutationStore] Unlike failed: \(error)")
                }
            }
        } else {
            likedPostIDs.insert(postId)
            overlayCallback?("heart.fill", .red)
            Task {
                do {
                    let insert = PublicSchema.LikesInsert(
                        createdAt: nil, postId: postId, userId: userId
                    )
                    try await SupabaseManager.client.from("likes")
                        .insert(insert)
                        .execute()
                    await cacheInvalidator?.postMutated(postId: postId, userId: userId)
                } catch {
                    likedPostIDs.remove(postId)
                    print("[PostMutationStore] Like failed: \(error)")
                }
            }
        }
    }

    // MARK: - Reset

    /// Clears all cached state (e.g. on sign-out).
    func reset() {
        pinnedPostIDs = []
        likedPostIDs = []
        currentUserId = nil
    }
}
