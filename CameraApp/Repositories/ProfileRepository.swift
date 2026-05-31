import Foundation
import SwiftData

// MARK: - Protocol

@MainActor
protocol ProfileRepository {
    func loadProfile(userId: UUID) async throws -> User
    func invalidate(userId: UUID)
}

// MARK: - Implementation

@MainActor @Observable
final class DefaultProfileRepository: ProfileRepository {
    nonisolated static let profileTTL: TimeInterval = 300

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Load

    func loadProfile(userId: UUID) async throws -> User {
        let key = "profile:\(userId.uuidString)"

        if let entry = fetchCacheEntry(key: key), entry.isFresh(ttl: Self.profileTTL) {
            let cached = fetchCachedUsers(cacheKey: key)
            if let first = cached.first {
                return first.toUser()
            }
        }

        do {
            let profile: PublicSchema.ProfilesSelect = try await SupabaseManager.client
                .from("profiles")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value

            saveCachedUser(CachedUser(from: profile, cacheKey: key), cacheKey: key)
            return User(from: profile)
        } catch {
            let cached = fetchCachedUsers(cacheKey: key)
            if let first = cached.first { return first.toUser() }
            throw error
        }
    }

    // MARK: - Invalidation

    func invalidate(userId: UUID) {
        let key = "profile:\(userId.uuidString)"
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
        let descriptor = FetchDescriptor<CachedUser>(
            predicate: #Predicate { $0.cacheKey == cacheKey }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func saveCachedUser(_ user: CachedUser, cacheKey: String) {
        let descriptor = FetchDescriptor<CachedUser>(
            predicate: #Predicate { $0.cacheKey == cacheKey }
        )
        if let existing = try? modelContext.fetch(descriptor) {
            for user in existing {
                modelContext.delete(user)
            }
        }

        modelContext.insert(user)

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
