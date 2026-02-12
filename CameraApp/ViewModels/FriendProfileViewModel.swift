import Observation
import SwiftUI

// MARK: - Friend Profile View Model

@Observable
final class FriendProfileViewModel {
    // MARK: - Input

    let user: User

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

    // MARK: - Actions

    /// Fetches the user's posts from Supabase. RLS handles scope filtering.
    func loadPosts() {
        isLoadingPosts = true
        postsError = nil

        Task { @MainActor in
            do {
                let rows: [PublicSchema.PostsSelect] = try await SupabaseManager.client
                    .from("posts")
                    .select()
                    .eq("user_id", value: user.id)
                    .order("created_at", ascending: false)
                    .execute()
                    .value

                userPosts = rows.map { ImagePost(from: $0, user: user) }
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
