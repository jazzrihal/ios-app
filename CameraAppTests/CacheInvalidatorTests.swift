@testable import Pinstoria
import Foundation
import SwiftData
import Testing

@Suite("CacheInvalidator")
struct CacheInvalidatorTests {
    @MainActor
    private func makeContext() -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer( // swiftlint:disable:this force_try
            for: CacheEntry.self, CachedPost.self, CachedUser.self, CachedMoment.self,
            configurations: config
        )
        return ModelContext(container)
    }

    @Test("postUploaded invalidates user posts and nearby caches")
    @MainActor
    func postUploaded() {
        let context = makeContext()
        let postRepo = DefaultPostRepository(modelContext: context)
        let invalidator = CacheInvalidator()
        invalidator.configure(
            posts: postRepo,
            friends: DefaultFriendRepository(modelContext: context),
            moments: DefaultMomentRepository(modelContext: context),
            profiles: DefaultProfileRepository(modelContext: context)
        )

        let userId = UUID()
        let userKey = "user_posts:\(userId.uuidString)"

        context.insert(CacheEntry(key: userKey))
        try? context.save()

        let entryBefore = try? context.fetch(
            FetchDescriptor<CacheEntry>(predicate: #Predicate { $0.key == userKey })
        ).first
        #expect(entryBefore != nil)

        invalidator.postUploaded(userId: userId)

        let entryAfter = try? context.fetch(
            FetchDescriptor<CacheEntry>(predicate: #Predicate { $0.key == userKey })
        ).first
        #expect(entryAfter == nil)
    }

    @Test("friendshipChanged invalidates friends cache")
    @MainActor
    func friendshipChanged() {
        let context = makeContext()
        let friendRepo = DefaultFriendRepository(modelContext: context)
        let invalidator = CacheInvalidator()
        invalidator.configure(
            posts: DefaultPostRepository(modelContext: context),
            friends: friendRepo,
            moments: DefaultMomentRepository(modelContext: context),
            profiles: DefaultProfileRepository(modelContext: context)
        )

        let userId = UUID()
        let key = "friends:\(userId.uuidString)"

        context.insert(CacheEntry(key: key))
        try? context.save()

        invalidator.friendshipChanged(userId: userId)

        let entryAfter = try? context.fetch(
            FetchDescriptor<CacheEntry>(predicate: #Predicate { $0.key == key })
        ).first
        #expect(entryAfter == nil)
    }

    @Test("momentsChanged invalidates moments cache")
    @MainActor
    func momentsChanged() {
        let context = makeContext()
        let momentRepo = DefaultMomentRepository(modelContext: context)
        let invalidator = CacheInvalidator()
        invalidator.configure(
            posts: DefaultPostRepository(modelContext: context),
            friends: DefaultFriendRepository(modelContext: context),
            moments: momentRepo,
            profiles: DefaultProfileRepository(modelContext: context)
        )

        context.insert(CacheEntry(key: "moments"))
        try? context.save()

        invalidator.momentsChanged()

        let entryAfter = try? context.fetch(
            FetchDescriptor<CacheEntry>(predicate: #Predicate { $0.key == "moments" })
        ).first
        #expect(entryAfter == nil)
    }

    @Test("postEdited invalidates user, feed, and nearby caches")
    @MainActor
    func postEdited() {
        let context = makeContext()
        let postRepo = DefaultPostRepository(modelContext: context)
        let invalidator = CacheInvalidator()
        invalidator.configure(
            posts: postRepo,
            friends: DefaultFriendRepository(modelContext: context),
            moments: DefaultMomentRepository(modelContext: context),
            profiles: DefaultProfileRepository(modelContext: context)
        )

        let userId = UUID()
        let userKey = "user_posts:\(userId.uuidString)"
        let feedKey = "friend_feed"
        let nearbyKey = "nearby_posts:37.775:-122.419:2026-03-07"

        context.insert(CacheEntry(key: userKey))
        context.insert(CacheEntry(key: feedKey))
        context.insert(CacheEntry(key: nearbyKey))
        try? context.save()

        invalidator.postEdited(userId: userId)

        let userAfter = try? context.fetch(
            FetchDescriptor<CacheEntry>(predicate: #Predicate { $0.key == userKey })
        ).first
        let feedAfter = try? context.fetch(
            FetchDescriptor<CacheEntry>(predicate: #Predicate { $0.key == feedKey })
        ).first
        let nearbyAfter = try? context.fetch(
            FetchDescriptor<CacheEntry>(predicate: #Predicate { $0.key == nearbyKey })
        ).first
        #expect(userAfter == nil)
        #expect(feedAfter == nil)
        #expect(nearbyAfter == nil)
    }

    @Test("postDeleted invalidates user, feed, and nearby caches")
    @MainActor
    func postDeleted() {
        let context = makeContext()
        let postRepo = DefaultPostRepository(modelContext: context)
        let invalidator = CacheInvalidator()
        invalidator.configure(
            posts: postRepo,
            friends: DefaultFriendRepository(modelContext: context),
            moments: DefaultMomentRepository(modelContext: context),
            profiles: DefaultProfileRepository(modelContext: context)
        )

        let userId = UUID()
        let userKey = "user_posts:\(userId.uuidString)"
        let feedKey = "friend_feed"
        let nearbyKey = "nearby_posts:40.000:-70.000:2026-03-07"

        context.insert(CacheEntry(key: userKey))
        context.insert(CacheEntry(key: feedKey))
        context.insert(CacheEntry(key: nearbyKey))
        try? context.save()

        invalidator.postDeleted(userId: userId)

        let userAfter = try? context.fetch(
            FetchDescriptor<CacheEntry>(predicate: #Predicate { $0.key == userKey })
        ).first
        let feedAfter = try? context.fetch(
            FetchDescriptor<CacheEntry>(predicate: #Predicate { $0.key == feedKey })
        ).first
        let nearbyAfter = try? context.fetch(
            FetchDescriptor<CacheEntry>(predicate: #Predicate { $0.key == nearbyKey })
        ).first
        #expect(userAfter == nil)
        #expect(feedAfter == nil)
        #expect(nearbyAfter == nil)
    }
}
