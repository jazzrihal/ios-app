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

    /// Set to `true` when the view should dismiss (e.g. after removing a friend).
    var shouldDismiss = false

    // MARK: - Init

    init(user: User) {
        self.user = user
    }

    // MARK: - Actions

    func loadPosts(store: FriendsStore) {
        let isFriend = store.status(for: user) == .friends
        userPosts = ImagePost.sampleUserPosts(for: user, isFriend: isFriend)
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
