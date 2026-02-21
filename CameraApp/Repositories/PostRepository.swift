import CoreLocation
import Foundation
import SwiftData

// MARK: - Protocol

@MainActor
protocol PostRepository {
    func nearbyPosts(params: NearbyPostsParams) async throws -> [ImagePost]
    func nearbyPostsNextPage(params: NearbyPostsParams) async throws -> [ImagePost]
    func userPostsAndPins(userId: UUID, pageSize: Int, pageOffset: Int) async throws -> [ImagePost]
    func friendFeedPosts(friendIds: [UUID], friends: [User], pageSize: Int, from: Int) async throws -> [ImagePost]
    func invalidateUserPosts(_ userId: UUID)
    func invalidateNearbyPosts()
    func invalidateFriendFeed()
}

// MARK: - Implementation

@MainActor @Observable
final class DefaultPostRepository: PostRepository {
    nonisolated static let nearbyPostsTTL: TimeInterval = 60
    nonisolated static let userPostsTTL: TimeInterval = 120
    nonisolated static let friendFeedTTL: TimeInterval = 60

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Nearby Posts

    func nearbyPosts(params: NearbyPostsParams) async throws -> [ImagePost] {
        let key = Self.nearbyPostsCacheKey(params)

        if let entry = fetchCacheEntry(key: key), entry.isFresh(ttl: Self.nearbyPostsTTL) {
            let cached = fetchCachedPosts(cacheKey: key)
            if !cached.isEmpty {
                return cached.map { $0.toImagePost() }
            }
        }

        do {
            let rows: [NearbyPostRow] = try await SupabaseManager.client
                .rpc("nearby_posts", params: params)
                .execute()
                .value

            saveCachedPosts(rows.enumerated().map { index, row in
                CachedPost(from: row, cacheKey: key, sortOrder: index)
            }, cacheKey: key)

            return rows.map { ImagePost(from: $0) }
        } catch {
            let cached = fetchCachedPosts(cacheKey: key)
            if !cached.isEmpty { return cached.map { $0.toImagePost() } }
            throw error
        }
    }

    func nearbyPostsNextPage(params: NearbyPostsParams) async throws -> [ImagePost] {
        let rows: [NearbyPostRow] = try await SupabaseManager.client
            .rpc("nearby_posts", params: params)
            .execute()
            .value
        return rows.map { ImagePost(from: $0) }
    }

    // MARK: - User Posts & Pins

    func userPostsAndPins(userId: UUID, pageSize: Int, pageOffset: Int) async throws -> [ImagePost] {
        let key = Self.userPostsCacheKey(userId)

        if pageOffset == 0,
           let entry = fetchCacheEntry(key: key),
           entry.isFresh(ttl: Self.userPostsTTL) {
            let cached = fetchCachedPosts(cacheKey: key)
            if !cached.isEmpty {
                return cached.map { $0.toImagePost() }
            }
        }

        let params = GetUserPostsAndPinsParams(
            targetUserId: userId, pageSize: pageSize, pageOffset: pageOffset
        )

        do {
            let rows: [UserPostWithPinRow] = try await SupabaseManager.client
                .rpc("get_user_posts_and_pins", params: params)
                .execute()
                .value

            if pageOffset == 0 {
                saveCachedPosts(rows.enumerated().map { index, row in
                    CachedPost(from: row, cacheKey: key, sortOrder: index)
                }, cacheKey: key)
            }

            return rows.map { row in
                var post = ImagePost(from: row)
                if row.isPinnedByUser {
                    post.pinnedByUsername = row.username
                }
                return post
            }
        } catch {
            if pageOffset == 0 {
                let cached = fetchCachedPosts(cacheKey: key)
                if !cached.isEmpty { return cached.map { $0.toImagePost() } }
            }
            throw error
        }
    }

    // MARK: - Friend Feed

    func friendFeedPosts(friendIds: [UUID], friends: [User], pageSize: Int, from: Int) async throws -> [ImagePost] {
        let key = "friend_feed"
        let userLookup = Dictionary(uniqueKeysWithValues: friends.map { ($0.id, $0) })

        if from == 0,
           let entry = fetchCacheEntry(key: key),
           entry.isFresh(ttl: Self.friendFeedTTL) {
            let cached = fetchCachedPosts(cacheKey: key)
            if !cached.isEmpty {
                return cached.map { $0.toImagePost() }
            }
        }

        do {
            let rows: [PostRowWithoutLocation] = try await SupabaseManager.client
                .from("posts")
                .select(PostRowWithoutLocation.selectColumns)
                .in("user_id", values: friendIds)
                .order("created_at", ascending: false)
                .range(from: from, to: from + pageSize - 1)
                .execute()
                .value

            if from == 0 {
                saveCachedPosts(rows.enumerated().compactMap { index, row -> CachedPost? in
                    guard let user = userLookup[row.userId] else { return nil }
                    let cached = CachedPost(from: row, cacheKey: key, sortOrder: index)
                    cached.username = user.username
                    cached.displayName = user.displayName
                    return cached
                }, cacheKey: key)
            }

            return rows.compactMap { row in
                guard let user = userLookup[row.userId] else { return nil }
                return ImagePost(
                    id: row.id,
                    imageURL: SupabaseManager.imageURL(for: row.imagePath),
                    user: user,
                    caption: row.caption ?? "",
                    coordinate: CLLocationCoordinate2D(
                        latitude: row.latitude, longitude: row.longitude
                    ),
                    locationName: row.locationName ?? "",
                    timestamp: ISO8601DateFormatter.flexibleParse(row.createdAt) ?? Date(),
                    distanceMeters: 0,
                    scope: PostScope(serverValue: row.scope)
                )
            }
        } catch {
            if from == 0 {
                let cached = fetchCachedPosts(cacheKey: key)
                if !cached.isEmpty { return cached.map { $0.toImagePost() } }
            }
            throw error
        }
    }

    // MARK: - Invalidation

    func invalidateUserPosts(_ userId: UUID) {
        let key = Self.userPostsCacheKey(userId)
        deleteCacheEntry(key: key)
    }

    func invalidateNearbyPosts() {
        let descriptor = FetchDescriptor<CacheEntry>(
            predicate: #Predicate { $0.key.contains("nearby_posts:") }
        )
        if let entries = try? modelContext.fetch(descriptor) {
            for entry in entries {
                modelContext.delete(entry)
            }
        }
        try? modelContext.save()
    }

    func invalidateFriendFeed() {
        deleteCacheEntry(key: "friend_feed")
    }

    // MARK: - Cache Key Builders

    private static func nearbyPostsCacheKey(_ params: NearbyPostsParams) -> String {
        let lat = String(format: "%.3f", params.lat)
        let lng = String(format: "%.3f", params.lng)
        return "nearby_posts:\(lat):\(lng):\(params.searchDate)"
    }

    private static func userPostsCacheKey(_ userId: UUID) -> String {
        "user_posts:\(userId.uuidString)"
    }

    // MARK: - SwiftData Helpers

    private func fetchCacheEntry(key: String) -> CacheEntry? {
        let descriptor = FetchDescriptor<CacheEntry>(
            predicate: #Predicate { $0.key == key }
        )
        return try? modelContext.fetch(descriptor).first
    }

    private func fetchCachedPosts(cacheKey: String) -> [CachedPost] {
        var descriptor = FetchDescriptor<CachedPost>(
            predicate: #Predicate { $0.cacheKey == cacheKey },
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        descriptor.fetchLimit = 100
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func saveCachedPosts(_ posts: [CachedPost], cacheKey: String) {
        deleteCachedPosts(cacheKey: cacheKey)

        for post in posts {
            modelContext.insert(post)
        }

        if let existing = fetchCacheEntry(key: cacheKey) {
            existing.fetchedAt = Date()
        } else {
            modelContext.insert(CacheEntry(key: cacheKey))
        }

        try? modelContext.save()
    }

    private func deleteCachedPosts(cacheKey: String) {
        let descriptor = FetchDescriptor<CachedPost>(
            predicate: #Predicate { $0.cacheKey == cacheKey }
        )
        if let existing = try? modelContext.fetch(descriptor) {
            for post in existing {
                modelContext.delete(post)
            }
        }
    }

    private func deleteCacheEntry(key: String) {
        if let entry = fetchCacheEntry(key: key) {
            modelContext.delete(entry)
        }
        deleteCachedPosts(cacheKey: key)
        try? modelContext.save()
    }
}
