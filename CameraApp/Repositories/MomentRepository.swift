import CoreLocation
import Foundation
import SwiftData

// MARK: - Protocol

@MainActor
protocol MomentRepository {
    func loadMomentsWithPosts() async throws -> ([Moment], [UUID: [ImagePost]])
    func invalidate()
}

// MARK: - Implementation

@MainActor @Observable
final class DefaultMomentRepository: MomentRepository {
    nonisolated static let momentsTTL: TimeInterval = 300

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Load

    func loadMomentsWithPosts() async throws -> ([Moment], [UUID: [ImagePost]]) {
        let key = currentViewerId().map { Self.momentsCacheKey(viewerId: $0) }

        if let key,
           let entry = fetchCacheEntry(key: key),
           entry.isFresh(ttl: Self.momentsTTL) {
            let cached = fetchCachedMoments(cacheKey: key)
            if !cached.isEmpty {
                let moments = cached.map { $0.toMoment() }
                let nearbyPosts = Dictionary(
                    uniqueKeysWithValues: cached.map { ($0.momentId, $0.toNearbyImagePosts()) }
                )
                return (moments, nearbyPosts)
            }
        }

        do {
            let params = MomentsWithNearbyPostsParams(
                radiusMeters: nil,
                dateRangeDays: nil,
                timeDecayHours: nil,
                distanceWeight: nil,
                postsPerMoment: 5
            )

            let rows: [MomentWithNearbyPostsRow] = try await SupabaseManager.client
                .rpc("moments_with_nearby_posts", params: params)
                .execute()
                .value

            if let key {
                saveCachedMoments(
                    rows.enumerated().map { i, row in
                        CachedMoment(from: row, cacheKey: key, sortOrder: i)
                    },
                    cacheKey: key
                )
            }

            let nearbyPosts = Dictionary(
                uniqueKeysWithValues: rows.map { row in
                    (row.momentId, row.nearbyPosts.map { ImagePost(from: $0) })
                }
            )
            let moments = rows.map { Moment(from: $0) }
            return (moments, nearbyPosts)
        } catch {
            if let key {
                let cached = fetchCachedMoments(cacheKey: key)
                if !cached.isEmpty {
                    let moments = cached.map { $0.toMoment() }
                    let nearbyPosts = Dictionary(
                        uniqueKeysWithValues: cached.map { ($0.momentId, $0.toNearbyImagePosts()) }
                    )
                    return (moments, nearbyPosts)
                }
            }
            throw error
        }
    }

    // MARK: - Invalidation

    func invalidate() {
        deleteCacheEntries { $0.contains("moments") }
    }

    func purgeAllCachedData() {
        deleteAll(CachedMoment.self)
        try? modelContext.save()
    }

    nonisolated static func momentsCacheKey(viewerId: UUID) -> String {
        "viewer:\(viewerId.uuidString):moments"
    }

    // MARK: - SwiftData Helpers

    private func currentViewerId() -> UUID? {
        SupabaseManager.client.auth.currentSession?.user.id
    }

    private func fetchCacheEntry(key: String) -> CacheEntry? {
        let descriptor = FetchDescriptor<CacheEntry>(
            predicate: #Predicate { $0.key == key }
        )
        return try? modelContext.fetch(descriptor).first
    }

    private func fetchCachedMoments(cacheKey: String) -> [CachedMoment] {
        var descriptor = FetchDescriptor<CachedMoment>(
            predicate: #Predicate { $0.cacheKey == cacheKey },
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        descriptor.fetchLimit = 100
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func saveCachedMoments(_ moments: [CachedMoment], cacheKey: String) {
        let descriptor = FetchDescriptor<CachedMoment>(
            predicate: #Predicate { $0.cacheKey == cacheKey }
        )
        if let existing = try? modelContext.fetch(descriptor) {
            for moment in existing {
                modelContext.delete(moment)
            }
        }

        for moment in moments {
            modelContext.insert(moment)
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
        let descriptor = FetchDescriptor<CachedMoment>(
            predicate: #Predicate { $0.cacheKey == key }
        )
        if let existing = try? modelContext.fetch(descriptor) {
            for moment in existing {
                modelContext.delete(moment)
            }
        }
        try? modelContext.save()
    }

    private func deleteCacheEntries(where shouldDelete: (String) -> Bool) {
        let entryDescriptor = FetchDescriptor<CacheEntry>()
        if let entries = try? modelContext.fetch(entryDescriptor) {
            for entry in entries where shouldDelete(entry.key) {
                modelContext.delete(entry)
            }
        }

        let momentDescriptor = FetchDescriptor<CachedMoment>()
        if let moments = try? modelContext.fetch(momentDescriptor) {
            for moment in moments where shouldDelete(moment.cacheKey) {
                modelContext.delete(moment)
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
