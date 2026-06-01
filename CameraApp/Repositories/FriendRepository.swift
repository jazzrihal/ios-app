import Foundation
import SwiftData

// MARK: - Protocol

@MainActor
protocol FriendRepository {
    func loadFriends(userId: UUID) async throws -> [User]
    func loadIncomingRequests(userId: UUID) async throws -> [User]
    func loadSentRequests(userId: UUID) async throws -> [User]
    func loadSuggestedUsers(userId: UUID, excludeIds: [UUID]) async throws -> [User]
    func searchUsers(query: String, excludeUserId: UUID?) async throws -> [User]
    func invalidate(userId: UUID)
}

// MARK: - Implementation

@MainActor @Observable
final class DefaultFriendRepository: FriendRepository {
    nonisolated static let friendsTTL: TimeInterval = 300

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Load Friends

    func loadFriends(userId: UUID) async throws -> [User] {
        let key = "friends:\(userId.uuidString)"

        if let entry = fetchCacheEntry(key: key), entry.isFresh(ttl: Self.friendsTTL) {
            let cached = fetchCachedUsers(cacheKey: key)
            // Return cached result even if empty (user genuinely has no friends)
            return cached.map { $0.toUser() }
        }

        do {
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
            guard !friendIds.isEmpty else {
                saveCachedUsers([], cacheKey: key)
                return []
            }

            let profiles: [PublicSchema.ProfilesSelect] = try await SupabaseManager.client
                .from("profiles")
                .select()
                .in("id", values: friendIds)
                .execute()
                .value

            let users = profiles.map { User(from: $0) }
            saveCachedUsers(
                profiles.enumerated().map { index, profile in
                    CachedUser(from: profile, cacheKey: key, sortOrder: index)
                },
                cacheKey: key
            )
            return users
        } catch {
            let cached = fetchCachedUsers(cacheKey: key)
            if !cached.isEmpty { return cached.map { $0.toUser() } }
            throw error
        }
    }

    // MARK: - Incoming Requests

    func loadIncomingRequests(userId: UUID) async throws -> [User] {
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

    // MARK: - Sent Requests

    func loadSentRequests(userId: UUID) async throws -> [User] {
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

    // MARK: - Suggested Users

    func loadSuggestedUsers(userId: UUID, excludeIds: [UUID]) async throws -> [User] {
        let allExcluded = excludeIds + [userId]
        let excludeList = "(\(allExcluded.map(\.uuidString).joined(separator: ",")))"

        let profiles: [PublicSchema.ProfilesSelect] = try await SupabaseManager.client
            .from("profiles")
            .select()
            .not("id", operator: .in, value: excludeList)
            .limit(20)
            .execute()
            .value

        return profiles.map { User(from: $0) }
    }

    // MARK: - Search

    func searchUsers(query: String, excludeUserId: UUID?) async throws -> [User] {
        let params = SearchUsersParams(query: query, maxResults: 20)
        let rows: [SearchUserRow] = try await SupabaseManager.client
            .rpc("search_users", params: params)
            .execute()
            .value

        return rows
            .map { User(from: $0) }
            .filter { $0.id != excludeUserId }
    }

    // MARK: - Invalidation

    func invalidate(userId: UUID) {
        let key = "friends:\(userId.uuidString)"
        deleteCacheEntry(key: key)
    }

    func purgeAllCachedData() {
        deleteAll(CachedUser.self)
        try? modelContext.save()
    }

    // MARK: - SwiftData Helpers

    private func fetchCacheEntry(key: String) -> CacheEntry? {
        let descriptor = FetchDescriptor<CacheEntry>(
            predicate: #Predicate { $0.key == key }
        )
        return try? modelContext.fetch(descriptor).first
    }

    private func fetchCachedUsers(cacheKey: String) -> [CachedUser] {
        var descriptor = FetchDescriptor<CachedUser>(
            predicate: #Predicate { $0.cacheKey == cacheKey },
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        descriptor.fetchLimit = 100
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func saveCachedUsers(_ users: [CachedUser], cacheKey: String) {
        let descriptor = FetchDescriptor<CachedUser>(
            predicate: #Predicate { $0.cacheKey == cacheKey }
        )
        if let existing = try? modelContext.fetch(descriptor) {
            for user in existing {
                modelContext.delete(user)
            }
        }

        for user in users {
            modelContext.insert(user)
        }

        if let entry = fetchCacheEntry(key: cacheKey) {
            entry.fetchedAt = Date()
        } else {
            modelContext.insert(CacheEntry(key: cacheKey))
        }

        try? modelContext.save()
    }

    private func deleteCacheEntry(key: String) {
        if let entry = fetchCacheEntry(key: key) {
            modelContext.delete(entry)
        }
        let descriptor = FetchDescriptor<CachedUser>(
            predicate: #Predicate { $0.cacheKey == key }
        )
        if let existing = try? modelContext.fetch(descriptor) {
            for user in existing {
                modelContext.delete(user)
            }
        }
        try? modelContext.save()
    }

    private func deleteAll<T: PersistentModel>(_: T.Type) {
        let descriptor = FetchDescriptor<T>()
        if let values = try? modelContext.fetch(descriptor) {
            for value in values {
                modelContext.delete(value)
            }
        }
    }
}
