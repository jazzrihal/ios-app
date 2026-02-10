import Foundation
import Observation

@Observable
class FriendsStore {
    var friends: [User] = User.sampleFriends()
    var suggestedUsers: [User] = User.sampleSuggested()
    var incomingRequests: [User] = User.sampleIncomingRequests()
    var pendingSentRequests: Set<UUID> = []

    // MARK: - Friend Status

    func status(for user: User) -> FriendStatus {
        if friends.contains(where: { $0.id == user.id }) {
            return .friends
        } else if pendingSentRequests.contains(user.id) {
            return .pendingSent
        } else if incomingRequests.contains(where: { $0.id == user.id }) {
            return .pendingReceived
        }
        return .none
    }

    // MARK: - Actions

    func sendRequest(to user: User) {
        guard status(for: user) == .none else { return }
        pendingSentRequests.insert(user.id)
    }

    func cancelRequest(to user: User) {
        pendingSentRequests.remove(user.id)
    }

    func acceptRequest(from user: User) {
        incomingRequests.removeAll { $0.id == user.id }
        friends.append(user)
        suggestedUsers.removeAll { $0.id == user.id }
    }

    func declineRequest(from user: User) {
        incomingRequests.removeAll { $0.id == user.id }
    }

    func removeFriend(_ user: User) {
        friends.removeAll { $0.id == user.id }
    }

    // MARK: - Search

    func searchUsers(query: String) -> [User] {
        guard !query.isEmpty else { return [] }
        let lowered = query.lowercased()
        let allSearchable = suggestedUsers + friends + incomingRequests

        var seen = Set<UUID>()
        return allSearchable.filter { user in
            seen.insert(user.id).inserted &&
                (user.username.lowercased().contains(lowered) ||
                    user.displayName.lowercased().contains(lowered))
        }
    }

    func searchFriends(query: String) -> [User] {
        guard !query.isEmpty else { return friends }
        let lowered = query.lowercased()
        return friends.filter {
            $0.username.lowercased().contains(lowered) ||
                $0.displayName.lowercased().contains(lowered)
        }
    }
}
