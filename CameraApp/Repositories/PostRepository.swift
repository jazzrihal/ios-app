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
    func updatePost(id: UUID, caption: String?, scope: PostScope) async throws
    func deletePost(id: UUID, imagePath: String) async throws
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
        let key = currentViewerId().map { Self.nearbyPostsCacheKey(params, viewerId: $0) }

        if let key,
           let entry = fetchCacheEntry(key: key),
           entry.isFresh(ttl: Self.nearbyPostsTTL) {
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

            if let key {
                saveCachedPosts(rows.enumerated().map { index, row in
                    CachedPost(from: row, cacheKey: key, sortOrder: index)
                }, cacheKey: key)
            }

            return rows.map { ImagePost(from: $0) }
        } catch {
            if let key {
                let cached = fetchCachedPosts(cacheKey: key)
                if !cached.isEmpty { return cached.map { $0.toImagePost() } }
            }
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
        let key = currentViewerId().map { Self.userPostsCacheKey(userId, viewerId: $0) }

        if pageOffset == 0,
           let key,
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

            if pageOffset == 0, let key {
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
            if pageOffset == 0, let key {
                let cached = fetchCachedPosts(cacheKey: key)
                if !cached.isEmpty { return cached.map { $0.toImagePost() } }
            }
            throw error
        }
    }

    // MARK: - Friend Feed

    func friendFeedPosts(friendIds: [UUID], friends: [User], pageSize: Int, from: Int) async throws -> [ImagePost] {
        let key = currentViewerId().map { Self.friendFeedCacheKey(viewerId: $0) }
        let userLookup = Dictionary(uniqueKeysWithValues: friends.map { ($0.id, $0) })

        if from == 0,
           let key,
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

            if from == 0, let key {
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
                    imagePath: row.imagePath,
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
            if from == 0, let key {
                let cached = fetchCachedPosts(cacheKey: key)
                if !cached.isEmpty { return cached.map { $0.toImagePost() } }
            }
            throw error
        }
    }

    // MARK: - Owner Mutations

    func updatePost(id: UUID, caption: String?, scope: PostScope) async throws {
        let updates = Self.makePostUpdate(caption: caption, scope: scope)

        try await SupabaseManager.client
            .from("posts")
            .update(updates)
            .eq("id", value: id)
            .execute()
    }

    func deletePost(id: UUID, imagePath: String) async throws {
        try await SupabaseManager.client
            .from("posts")
            .delete()
            .eq("id", value: id)
            .execute()

        try await SupabaseManager.client
            .storage
            .from("post-images")
            .remove(paths: [imagePath])
    }

    nonisolated static func makePostUpdate(caption: String?, scope: PostScope) -> PublicSchema.PostsUpdate {
        PublicSchema.PostsUpdate(
            caption: normalizedCaption(caption),
            createdAt: nil,
            id: nil,
            imagePath: nil,
            latitude: nil,
            location: nil,
            locationName: nil,
            longitude: nil,
            scope: scope.databaseValue,
            userId: nil
        )
    }

    nonisolated static func normalizedCaption(_ caption: String?) -> String? {
        guard let caption else { return nil }
        let trimmed = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    nonisolated static func canMutatePost(ownerId: UUID, viewerId: UUID?) -> Bool {
        ownerId == viewerId
    }

    // MARK: - Invalidation

    func invalidateUserPosts(_ userId: UUID) {
        deleteCacheEntries { $0.contains("user_posts:\(userId.uuidString)") }
    }

    func invalidateNearbyPosts() {
        deleteCacheEntries { $0.contains("nearby_posts:") }
    }

    func invalidateFriendFeed() {
        deleteCacheEntries { $0.contains("friend_feed") }
    }

    func purgeAllCachedData() {
        deleteAll(CacheEntry.self)
        deleteAll(CachedPost.self)
        try? modelContext.save()
    }

    // MARK: - Cache Key Builders

    nonisolated static func nearbyPostsCacheKey(_ params: NearbyPostsParams, viewerId: UUID) -> String {
        let lat = String(format: "%.3f", params.lat)
        let lng = String(format: "%.3f", params.lng)
        return "viewer:\(viewerId.uuidString):nearby_posts:\(lat):\(lng):\(params.searchDate)"
    }

    nonisolated static func userPostsCacheKey(_ userId: UUID, viewerId: UUID) -> String {
        "viewer:\(viewerId.uuidString):user_posts:\(userId.uuidString)"
    }

    nonisolated static func friendFeedCacheKey(viewerId: UUID) -> String {
        "viewer:\(viewerId.uuidString):friend_feed"
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

    private func deleteCacheEntries(where shouldDelete: (String) -> Bool) {
        let entryDescriptor = FetchDescriptor<CacheEntry>()
        if let entries = try? modelContext.fetch(entryDescriptor) {
            for entry in entries where shouldDelete(entry.key) {
                modelContext.delete(entry)
            }
        }

        let postDescriptor = FetchDescriptor<CachedPost>()
        if let posts = try? modelContext.fetch(postDescriptor) {
            for post in posts where shouldDelete(post.cacheKey) {
                modelContext.delete(post)
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
