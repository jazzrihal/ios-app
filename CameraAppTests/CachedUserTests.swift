@testable import CameraApp
import Foundation
import SwiftData
import Testing

@Suite("CachedUser round-trip conversions")
struct CachedUserTests {
    @Test("ProfilesSelect round-trips through CachedUser correctly")
    func profilesSelectRoundTrip() {
        let profile = PublicSchema.ProfilesSelect(
            bio: "Hello world",
            createdAt: "2024-06-15T08:30:00.000Z",
            displayName: "Jane Doe",
            friendCount: 42,
            gradientColors: ["#3B82F6", "#8B5CF6"],
            id: UUID(),
            postCount: 87,
            username: "janedoe"
        )

        let cached = CachedUser(from: profile, cacheKey: "profile:abc", sortOrder: 0)
        let user = cached.toUser()

        #expect(user.id == profile.id)
        #expect(user.username == "janedoe")
        #expect(user.displayName == "Jane Doe")
        #expect(user.bio == "Hello world")
        #expect(user.postCount == 87)
        #expect(user.friendCount == 42)
        #expect(user.gradientColors.count == 2)
    }

    @Test("ProfilesSelect with nil optional fields")
    func profilesSelectNilFields() {
        let profile = PublicSchema.ProfilesSelect(
            bio: nil,
            createdAt: nil,
            displayName: "No Bio",
            friendCount: nil,
            gradientColors: nil,
            id: UUID(),
            postCount: nil,
            username: "nobio"
        )

        let cached = CachedUser(from: profile, cacheKey: "k", sortOrder: 0)
        let user = cached.toUser()

        #expect(user.bio.isEmpty)
        #expect(user.postCount == 0)
        #expect(user.friendCount == 0)
    }

    @Test("CachedUser preserves sort order and cache key")
    func cacheMetadata() {
        let profile = PublicSchema.ProfilesSelect(
            bio: nil,
            createdAt: "2025-01-01T00:00:00Z",
            displayName: "Test",
            friendCount: 0,
            gradientColors: nil,
            id: UUID(),
            postCount: 0,
            username: "test"
        )

        let cached = CachedUser(from: profile, cacheKey: "friends:xyz", sortOrder: 5)

        #expect(cached.cacheKey == "friends:xyz")
        #expect(cached.sortOrder == 5)
    }
}
