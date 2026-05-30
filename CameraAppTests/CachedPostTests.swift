import CoreLocation
import Foundation
@testable import Pinstoria
import SwiftData
import Testing

@Suite("CachedPost round-trip conversions")
struct CachedPostTests {
    // MARK: - NearbyPostRow Round-Trip

    @Test("NearbyPostRow round-trips through CachedPost correctly")
    func nearbyPostRowRoundTrip() {
        let row = NearbyPostRow(
            id: UUID(),
            userId: UUID(),
            username: "testuser",
            displayName: "Test User",
            gradientColors: ["#FF0000", "#00FF00"],
            imagePath: "images/test.jpg",
            caption: "A beautiful sunset",
            longitude: -122.4194,
            latitude: 37.7749,
            locationName: "San Francisco",
            scope: "public",
            createdAt: "2025-01-15T10:30:00.000Z",
            distanceMeters: 1234.5,
            totalCount: 42,
            isLikedByViewer: true,
            isPinnedByViewer: false
        )

        let cached = CachedPost(from: row, cacheKey: "test_key", sortOrder: 3)
        let post = cached.toImagePost()

        #expect(post.id == row.id)
        #expect(post.user.id == row.userId)
        #expect(post.user.username == "testuser")
        #expect(post.user.displayName == "Test User")
        #expect(post.caption == "A beautiful sunset")
        #expect(post.coordinate.latitude == 37.7749)
        #expect(post.coordinate.longitude == -122.4194)
        #expect(post.locationName == "San Francisco")
        #expect(post.scope == .public)
        #expect(post.distanceMeters == 1234.5)
        #expect(post.isLikedByViewer == true)
        #expect(post.isPinnedByViewer == false)
        #expect(post.hasViewerState == true)

        #expect(cached.cacheKey == "test_key")
        #expect(cached.sortOrder == 3)
        #expect(cached.totalCount == 42)
    }

    @Test("NearbyPostRow with nil optional fields")
    func nearbyPostRowNilFields() {
        let row = NearbyPostRow(
            id: UUID(),
            userId: UUID(),
            username: "user",
            displayName: "User",
            gradientColors: nil,
            imagePath: "img.jpg",
            caption: nil,
            longitude: 0,
            latitude: 0,
            locationName: nil,
            scope: "private",
            createdAt: "2025-01-01T00:00:00Z",
            distanceMeters: 0,
            totalCount: nil,
            isLikedByViewer: false,
            isPinnedByViewer: false
        )

        let cached = CachedPost(from: row, cacheKey: "k", sortOrder: 0)
        let post = cached.toImagePost()

        #expect(post.caption.isEmpty)
        #expect(post.locationName.isEmpty)
        #expect(cached.totalCount == 0)
        #expect(cached.gradientColorHexes.isEmpty)
    }

    // MARK: - UserPostWithPinRow Round-Trip

    @Test("UserPostWithPinRow round-trips with pinned state")
    func userPostWithPinRoundTrip() {
        let row = UserPostWithPinRow(
            id: UUID(),
            userId: UUID(),
            username: "pinuser",
            displayName: "Pin User",
            gradientColors: ["#0000FF"],
            imagePath: "pinned.jpg",
            caption: "Pinned post",
            longitude: -73.9857,
            latitude: 40.7484,
            locationName: "New York",
            scope: "friends",
            createdAt: "2025-06-01T12:00:00.000Z",
            isOwnPost: false,
            isPinnedByUser: true,
            isLikedByViewer: true,
            isPinnedByViewer: true,
            totalCount: 10
        )

        let cached = CachedPost(from: row, cacheKey: "user_posts:abc", sortOrder: 0)
        let post = cached.toImagePost()

        #expect(post.isPinnedByUser == true)
        #expect(post.isOwnPost == false)
        #expect(post.isLikedByViewer == true)
        #expect(post.isPinnedByViewer == true)
        #expect(post.pinnedByUsername == "pinuser")
        #expect(post.scope == .friends)
        #expect(post.distanceMeters == 0)
    }

    @Test("UserPostWithPinRow non-pinned post has nil pinnedByUsername")
    func userPostNotPinned() {
        let row = UserPostWithPinRow(
            id: UUID(),
            userId: UUID(),
            username: "someone",
            displayName: "Someone",
            gradientColors: nil,
            imagePath: "img.jpg",
            caption: nil,
            longitude: 0,
            latitude: 0,
            locationName: nil,
            scope: "public",
            createdAt: "2025-01-01T00:00:00Z",
            isOwnPost: true,
            isPinnedByUser: false,
            isLikedByViewer: false,
            isPinnedByViewer: false,
            totalCount: 5
        )

        let cached = CachedPost(from: row, cacheKey: "k", sortOrder: 0)
        let post = cached.toImagePost()

        #expect(post.pinnedByUsername == nil)
        #expect(post.isOwnPost == true)
    }

    // MARK: - PostRowWithoutLocation Round-Trip

    @Test("PostRowWithoutLocation creates CachedPost with empty user fields")
    func postRowWithoutLocationConversion() {
        let row = PostRowWithoutLocation(
            id: UUID(),
            userId: UUID(),
            imagePath: "feed/photo.jpg",
            caption: "Feed post",
            latitude: 51.5074,
            longitude: -0.1278,
            locationName: "London",
            scope: "public",
            createdAt: "2025-03-20T15:00:00.000Z"
        )

        let cached = CachedPost(from: row, cacheKey: "friend_feed", sortOrder: 2)

        #expect(cached.username.isEmpty)
        #expect(cached.displayName.isEmpty)
        #expect(cached.gradientColorHexes.isEmpty)
        #expect(cached.distanceMeters == 0)
        #expect(cached.caption == "Feed post")
    }
}
