import Foundation
import Observation

@Observable
class FriendsStore {
    var friends: [User] = User.sampleFriends()
    var suggestedUsers: [User] = User.sampleSuggested()
    var incomingRequests: [User] = User.sampleIncomingRequests()
    var pendingSentRequests: Set<UUID> = []
    var conversations: [Conversation] = []

    init() {
        conversations = Conversation.sampleConversations(friends: friends)
    }

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

        // Create an empty conversation
        if !conversations.contains(where: { $0.id == user.id }) {
            conversations.insert(
                Conversation(id: user.id, user: user, messages: [], unreadCount: 0),
                at: 0
            )
        }
    }

    func declineRequest(from user: User) {
        incomingRequests.removeAll { $0.id == user.id }
    }

    func removeFriend(_ user: User) {
        friends.removeAll { $0.id == user.id }
        conversations.removeAll { $0.id == user.id }
    }

    // MARK: - Chat

    func sendMessage(to userId: UUID, text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let message = ChatMessage(
            id: UUID(),
            senderId: User.currentUser.id,
            text: text.trimmingCharacters(in: .whitespacesAndNewlines),
            timestamp: Date(),
            isFromCurrentUser: true
        )

        if let index = conversations.firstIndex(where: { $0.id == userId }) {
            conversations[index].messages.append(message)
            // Move conversation to top
            let conversation = conversations.remove(at: index)
            conversations.insert(conversation, at: 0)
        }
    }

    func markAsRead(userId: UUID) {
        if let index = conversations.firstIndex(where: { $0.id == userId }) {
            conversations[index].unreadCount = 0
        }
    }

    var totalUnreadCount: Int {
        conversations.reduce(0) { $0 + $1.unreadCount }
    }

    // MARK: - Search

    func searchUsers(query: String) -> [User] {
        guard !query.isEmpty else { return suggestedUsers }
        let lowered = query.lowercased()
        let allSearchable = suggestedUsers + friends + incomingRequests
        let unique = Dictionary(grouping: allSearchable, by: \.id).compactMap(\.value.first)
        return unique.filter {
            $0.username.lowercased().contains(lowered) ||
            $0.displayName.lowercased().contains(lowered)
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
