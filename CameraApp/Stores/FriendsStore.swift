import Foundation
import Observation

@MainActor @Observable
class FriendsStore {
    var friends: [User] = []
    var suggestedUsers: [User] = []
    var incomingRequests: [User] = []
    var pendingSentRequests: Set<UUID> = []
    var isLoading = false
    var isRefreshing = false
    var errorMessage: String?
    var lastRefreshError: String?

    // Search state
    var searchResults: [User] = []
    var isSearching = false

    /// The authenticated user's UUID. Must be set before calling any methods.
    var currentUserId: UUID?

    /// Repository for data fetching (set from CameraAppApp on auth).
    var repository: (any FriendRepository)?

    /// Cache invalidator for notifying other layers of friendship changes.
    var cacheInvalidator: CacheInvalidator?

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

    /// Fetches friends, incoming requests, and suggested users.
    func loadAll() async {
        guard let userId = currentUserId else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        if let repo = repository {
            await loadAllViaRepository(repo, userId: userId)
        } else {
            await loadAllDirectly(userId: userId)
        }
    }

    /// Invalidates cached friend graph and reloads friends/requests/suggestions.
    func refreshAll() async {
        guard !isRefreshing else { return }
        guard let userId = currentUserId else { return }
        isRefreshing = true
        lastRefreshError = nil
        defer { isRefreshing = false }
        repository?.invalidate(userId: userId)
        await loadAll()
    }

    private func loadAllViaRepository(_ repo: any FriendRepository, userId: UUID) async {
        async let friendsResult = Result { try await repo.loadFriends(userId: userId) }
        async let incomingResult = Result { try await repo.loadIncomingRequests(userId: userId) }
        async let sentResult = Result { try await repo.loadSentRequests(userId: userId) }

        let (fr, ir, sr) = await (friendsResult, incomingResult, sentResult)
        guard isLoadContextCurrent(userId) else { return }
        applyFriendsResult(fr)
        applyIncomingResult(ir)
        applySentResult(sr)

        let excludeIds = friends.map(\.id)
            + incomingRequests.map(\.id)
            + Array(pendingSentRequests)

        do {
            let suggested = try await repo.loadSuggestedUsers(
                userId: userId, excludeIds: excludeIds
            )
            guard isLoadContextCurrent(userId) else { return }
            suggestedUsers = suggested
        } catch is CancellationError {
            return
        } catch {
            guard isLoadContextCurrent(userId) else { return }
            applyNonCancellationError(error)
        }
    }

    private func loadAllDirectly(userId: UUID) async {
        async let friendsResult = Result { try await loadFriendsDirectly(userId: userId) }
        async let incomingResult = Result { try await loadIncomingRequestsDirectly(userId: userId) }
        async let sentResult = Result { try await loadSentRequestsDirectly(userId: userId) }
        async let suggestedResult = Result { try await loadSuggestedUsersDirectly(userId: userId) }

        let (fr, ir, sr, sgr) = await (friendsResult, incomingResult, sentResult, suggestedResult)
        guard isLoadContextCurrent(userId) else { return }
        applyFriendsResult(fr)
        applyIncomingResult(ir)
        applySentResult(sr)
        applySuggestedResult(sgr)
    }

    private func applyFriendsResult(_ result: Result<[User], Error>) {
        switch result {
        case let .success(value): friends = value
        case let .failure(error): applyNonCancellationError(error)
        }
    }

    private func applyIncomingResult(_ result: Result<[User], Error>) {
        switch result {
        case let .success(value): incomingRequests = value
        case let .failure(error): applyNonCancellationError(error)
        }
    }

    private func applySentResult(_ result: Result<[User], Error>) {
        switch result {
        case let .success(value): pendingSentRequests = Set(value.map(\.id))
        case let .failure(error): applyNonCancellationError(error)
        }
    }

    private func applySuggestedResult(_ result: Result<[User], Error>) {
        switch result {
        case let .success(value): suggestedUsers = value
        case let .failure(error): applyNonCancellationError(error)
        }
    }

    private func applyNonCancellationError(_ error: Error) {
        guard !(error is CancellationError) else { return }
        let message = error.localizedDescription
        errorMessage = message
        lastRefreshError = message
    }

    private func isLoadContextCurrent(_ requestedUserId: UUID) -> Bool {
        guard !Task.isCancelled else { return false }
        return currentUserId == requestedUserId
    }

    // MARK: - Actions

    func sendRequest(to user: User) {
        guard let userId = currentUserId, status(for: user) == .none else { return }

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
                cacheInvalidator?.friendshipChanged(userId: userId)
            } catch {
                pendingSentRequests.remove(user.id)
                suggestedUsers.append(user)
                errorMessage = error.localizedDescription
            }
        }
    }

    func cancelRequest(to user: User) {
        guard let userId = currentUserId else { return }

        pendingSentRequests.remove(user.id)

        Task {
            do {
                try await SupabaseManager.client.from("friendships")
                    .delete()
                    .eq("requester_id", value: userId)
                    .eq("addressee_id", value: user.id)
                    .execute()
                cacheInvalidator?.friendshipChanged(userId: userId)
            } catch {
                pendingSentRequests.insert(user.id)
                errorMessage = error.localizedDescription
            }
        }
    }

    func acceptRequest(from user: User) {
        guard let userId = currentUserId else { return }

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
                cacheInvalidator?.friendshipChanged(userId: userId)
            } catch {
                friends.removeAll { $0.id == user.id }
                incomingRequests.append(user)
                errorMessage = error.localizedDescription
            }
        }
    }

    func declineRequest(from user: User) {
        guard let userId = currentUserId else { return }

        let removed = incomingRequests.first { $0.id == user.id }
        incomingRequests.removeAll { $0.id == user.id }

        Task {
            do {
                try await SupabaseManager.client.from("friendships")
                    .delete()
                    .eq("requester_id", value: user.id)
                    .eq("addressee_id", value: userId)
                    .execute()
                cacheInvalidator?.friendshipChanged(userId: userId)
            } catch {
                if let removed { incomingRequests.append(removed) }
                errorMessage = error.localizedDescription
            }
        }
    }

    func removeFriend(_ user: User) {
        guard let userId = currentUserId else { return }

        let removed = friends.first { $0.id == user.id }
        friends.removeAll { $0.id == user.id }

        Task {
            do {
                try await SupabaseManager.client.from("friendships")
                    .delete()
                    .or("and(requester_id.eq.\(userId),addressee_id.eq.\(user.id)),and(requester_id.eq.\(user.id),addressee_id.eq.\(userId))")
                    .execute()
                cacheInvalidator?.friendshipChanged(userId: userId)
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
            if let repo = repository {
                searchResults = try await repo.searchUsers(
                    query: trimmed, excludeUserId: currentUserId
                )
            } else {
                let params = SearchUsersParams(query: trimmed, maxResults: 20)
                let rows: [SearchUserRow] = try await SupabaseManager.client
                    .rpc("search_users", params: params)
                    .execute()
                    .value

                searchResults = rows
                    .map { User(from: $0) }
                    .filter { $0.id != currentUserId }
            }
        } catch {
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

    // MARK: - Session Reset

    func resetSessionState() {
        friends = []
        suggestedUsers = []
        incomingRequests = []
        pendingSentRequests = []
        searchResults = []
        isLoading = false
        isRefreshing = false
        isSearching = false
        errorMessage = nil
        lastRefreshError = nil
        currentUserId = nil
    }

    // MARK: - Direct Supabase Helpers (fallback when no repository)

    private func loadFriendsDirectly(userId: UUID) async throws -> [User] {
        let asRequester: [PublicSchema.FriendshipsSelect] = try await SupabaseManager.client
            .from("friendships")
            .select()
            .eq("requester_id", value: userId)
            .eq("status", value: "accepted")
            .execute()
            .value

        let asAddressee: [PublicSchema.FriendshipsSelect] = try await SupabaseManager.client
            .from("friendships")
            .select()
            .eq("addressee_id", value: userId)
            .eq("status", value: "accepted")
            .execute()
            .value

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

    private func loadIncomingRequestsDirectly(userId: UUID) async throws -> [User] {
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

    private func loadSentRequestsDirectly(userId: UUID) async throws -> [User] {
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

    private func loadSuggestedUsersDirectly(userId: UUID) async throws -> [User] {
        let excludeIds = friends.map(\.id)
            + incomingRequests.map(\.id)
            + Array(pendingSentRequests)
            + [userId]

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
