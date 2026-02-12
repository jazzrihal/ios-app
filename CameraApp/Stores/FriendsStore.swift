import Foundation
import Observation

@Observable
class FriendsStore {
    var friends: [User] = []
    var suggestedUsers: [User] = []
    var incomingRequests: [User] = []
    var pendingSentRequests: Set<UUID> = []
    var isLoading = false
    var errorMessage: String?

    // Search state
    var searchResults: [User] = []
    var isSearching = false

    /// The authenticated user's UUID. Must be set before calling any methods.
    var currentUserId: UUID?

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

    // MARK: - Load Data

    /// Fetches friends, incoming requests, and suggested users from Supabase.
    func loadAll() async {
        guard let userId = currentUserId else { return }
        isLoading = true
        errorMessage = nil

        // Load friends, requests, and suggestions independently so that a
        // failure in one (e.g. suggested users) doesn't discard the others.
        async let friendsResult = Result { try await loadFriends(userId: userId) }
        async let incomingResult = Result { try await loadIncomingRequests(userId: userId) }
        async let sentResult = Result { try await loadSentRequests(userId: userId) }
        async let suggestedResult = Result { try await loadSuggestedUsers(userId: userId) }

        let (fr, ir, sr, sgr) = await (friendsResult, incomingResult, sentResult, suggestedResult)

        switch fr {
        case let .success(value): friends = value
        case let .failure(error): errorMessage = error.localizedDescription
        }
        switch ir {
        case let .success(value): incomingRequests = value
        case let .failure(error): errorMessage = error.localizedDescription
        }
        switch sr {
        case let .success(value): pendingSentRequests = Set(value.map(\.id))
        case let .failure(error): errorMessage = error.localizedDescription
        }
        switch sgr {
        case let .success(value): suggestedUsers = value
        case let .failure(error): errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Actions

    func sendRequest(to user: User) {
        guard let userId = currentUserId, status(for: user) == .none else { return }

        // Optimistic update
        pendingSentRequests.insert(user.id)
        suggestedUsers.removeAll { $0.id == user.id }

        Task {
            do {
                let insert = PublicSchema.FriendshipsInsert(
                    addresseeId: user.id,
                    createdAt: nil,
                    requesterId: userId,
                    status: "pending"
                )
                try await SupabaseManager.client.from("friendships").insert(insert).execute()
            } catch {
                // Revert on failure
                pendingSentRequests.remove(user.id)
                suggestedUsers.append(user)
                errorMessage = error.localizedDescription
            }
        }
    }

    func cancelRequest(to user: User) {
        guard let userId = currentUserId else { return }

        // Optimistic update
        pendingSentRequests.remove(user.id)

        Task {
            do {
                try await SupabaseManager.client.from("friendships")
                    .delete()
                    .eq("requester_id", value: userId)
                    .eq("addressee_id", value: user.id)
                    .execute()
            } catch {
                pendingSentRequests.insert(user.id)
                errorMessage = error.localizedDescription
            }
        }
    }

    func acceptRequest(from user: User) {
        guard let userId = currentUserId else { return }

        // Optimistic update
        incomingRequests.removeAll { $0.id == user.id }
        friends.append(user)
        suggestedUsers.removeAll { $0.id == user.id }

        Task {
            do {
                try await SupabaseManager.client.from("friendships")
                    .update(PublicSchema.FriendshipsUpdate(
                        addresseeId: nil, createdAt: nil, requesterId: nil,
                        status: "accepted"
                    ))
                    .eq("requester_id", value: user.id)
                    .eq("addressee_id", value: userId)
                    .execute()
            } catch {
                // Revert
                friends.removeAll { $0.id == user.id }
                incomingRequests.append(user)
                errorMessage = error.localizedDescription
            }
        }
    }

    func declineRequest(from user: User) {
        guard let userId = currentUserId else { return }

        // Optimistic update
        let removed = incomingRequests.first { $0.id == user.id }
        incomingRequests.removeAll { $0.id == user.id }

        Task {
            do {
                try await SupabaseManager.client.from("friendships")
                    .delete()
                    .eq("requester_id", value: user.id)
                    .eq("addressee_id", value: userId)
                    .execute()
            } catch {
                if let removed { incomingRequests.append(removed) }
                errorMessage = error.localizedDescription
            }
        }
    }

    func removeFriend(_ user: User) {
        guard let userId = currentUserId else { return }

        // Optimistic update
        let removed = friends.first { $0.id == user.id }
        friends.removeAll { $0.id == user.id }

        Task {
            do {
                // The friendship row could have the current user as requester or addressee.
                // Delete both possible directions (only one will match).
                try await SupabaseManager.client.from("friendships")
                    .delete()
                    .or("and(requester_id.eq.\(userId),addressee_id.eq.\(user.id)),and(requester_id.eq.\(user.id),addressee_id.eq.\(userId))")
                    .execute()
            } catch {
                if let removed { friends.append(removed) }
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Search

    /// Searches for users via the `search_users` Supabase RPC.
    func remoteSearchUsers(query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            searchResults = []
            return
        }

        isSearching = true

        do {
            let params = SearchUsersParams(query: trimmed, maxResults: 20)
            let rows: [SearchUserRow] = try await SupabaseManager.client
                .rpc("search_users", params: params)
                .execute()
                .value

            // Exclude the current user from results
            searchResults = rows
                .map { User(from: $0) }
                .filter { $0.id != currentUserId }
        } catch {
            // On cancellation, don't overwrite results or show errors
            if Task.isCancelled { return }
            searchResults = []
            errorMessage = error.localizedDescription
        }

        if !Task.isCancelled {
            isSearching = false
        }
    }

    /// Clears remote search results.
    func clearSearchResults() {
        searchResults = []
        isSearching = false
    }

    func searchFriends(query: String) -> [User] {
        guard !query.isEmpty else { return friends }
        let lowered = query.lowercased()
        return friends.filter {
            $0.username.lowercased().contains(lowered) ||
                $0.displayName.lowercased().contains(lowered)
        }
    }

    // MARK: - Private Helpers

    /// Load accepted friends by querying friendships + joining profiles.
    private func loadFriends(userId: UUID) async throws -> [User] {
        // Friendships where current user is requester
        let asRequester: [PublicSchema.FriendshipsSelect] = try await SupabaseManager.client
            .from("friendships")
            .select()
            .eq("requester_id", value: userId)
            .eq("status", value: "accepted")
            .execute()
            .value

        // Friendships where current user is addressee
        let asAddressee: [PublicSchema.FriendshipsSelect] = try await SupabaseManager.client
            .from("friendships")
            .select()
            .eq("addressee_id", value: userId)
            .eq("status", value: "accepted")
            .execute()
            .value

        // Collect the other user's IDs
        let friendIds = asRequester.map(\.addresseeId) + asAddressee.map(\.requesterId)
        guard !friendIds.isEmpty else { return [] }

        let profiles: [PublicSchema.ProfilesSelect] = try await SupabaseManager.client
            .from("profiles")
            .select()
            .in("id", values: friendIds)
            .execute()
            .value

        return profiles.map { User(from: $0) }
    }

    /// Load pending incoming requests.
    private func loadIncomingRequests(userId: UUID) async throws -> [User] {
        let rows: [PublicSchema.FriendshipsSelect] = try await SupabaseManager.client
            .from("friendships")
            .select()
            .eq("addressee_id", value: userId)
            .eq("status", value: "pending")
            .execute()
            .value

        let requesterIds = rows.map(\.requesterId)
        guard !requesterIds.isEmpty else { return [] }

        let profiles: [PublicSchema.ProfilesSelect] = try await SupabaseManager.client
            .from("profiles")
            .select()
            .in("id", values: requesterIds)
            .execute()
            .value

        return profiles.map { User(from: $0) }
    }

    /// Load pending sent requests (so we can populate `pendingSentRequests`).
    private func loadSentRequests(userId: UUID) async throws -> [User] {
        let rows: [PublicSchema.FriendshipsSelect] = try await SupabaseManager.client
            .from("friendships")
            .select()
            .eq("requester_id", value: userId)
            .eq("status", value: "pending")
            .execute()
            .value

        let addresseeIds = rows.map(\.addresseeId)
        guard !addresseeIds.isEmpty else { return [] }

        let profiles: [PublicSchema.ProfilesSelect] = try await SupabaseManager.client
            .from("profiles")
            .select()
            .in("id", values: addresseeIds)
            .execute()
            .value

        return profiles.map { User(from: $0) }
    }

    /// Load suggested users (profiles that are not the current user and not already friends/pending).
    private func loadSuggestedUsers(userId: UUID) async throws -> [User] {
        let excludeIds = friends.map(\.id)
            + incomingRequests.map(\.id)
            + Array(pendingSentRequests)
            + [userId]

        // Format as a parenthesized list — PostgREST `in` filters require
        // `(val1,val2,…)` syntax; passing a Swift array directly produces
        // `{…}` which PostgREST rejects.
        let excludeList = "(\(excludeIds.map(\.uuidString).joined(separator: ",")))"

        let profiles: [PublicSchema.ProfilesSelect] = try await SupabaseManager.client
            .from("profiles")
            .select()
            .not("id", operator: .in, value: excludeList)
            .limit(20)
            .execute()
            .value

        return profiles.map { User(from: $0) }
    }
}
