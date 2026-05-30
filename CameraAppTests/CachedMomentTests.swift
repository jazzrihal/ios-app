@testable import Pinstoria
import CoreLocation
import Foundation
import SwiftData
import Testing

@Suite("CachedMoment round-trip conversions")
struct CachedMomentTests {
    @Test("MomentWithNearbyPostsRow round-trips through CachedMoment")
    func momentRoundTrip() {
        let nearbyPost = NearbyPostRow(
            id: UUID(),
            userId: UUID(),
            username: "nearby",
            displayName: "Nearby User",
            gradientColors: nil,
            imagePath: "post.jpg",
            caption: "Nearby",
            longitude: -122.0,
            latitude: 37.0,
            locationName: "Here",
            scope: "public",
            createdAt: "2025-01-01T00:00:00Z",
            distanceMeters: 500,
            totalCount: 1,
            isLikedByViewer: false,
            isPinnedByViewer: false
        )

        let row = MomentWithNearbyPostsRow(
            momentId: UUID(),
            longitude: -122.4194,
            latitude: 37.7749,
            locationName: "San Francisco",
            momentDate: "2025-06-15T10:00:00.000Z",
            createdAt: "2025-06-15T10:05:00.000Z",
            nearbyPosts: [nearbyPost]
        )

        let cached = CachedMoment(from: row, cacheKey: "moments", sortOrder: 0)
        let moment = cached.toMoment()

        #expect(moment.id == row.momentId)
        #expect(moment.locationName == "San Francisco")
        #expect(moment.coordinate.latitude == 37.7749)
        #expect(moment.coordinate.longitude == -122.4194)

        let posts = cached.toNearbyImagePosts()
        #expect(posts.count == 1)
        #expect(posts.first?.user.username == "nearby")
        #expect(posts.first?.caption == "Nearby")
    }

    @Test("CachedMoment with no nearby posts")
    func momentNoNearbyPosts() {
        let row = MomentWithNearbyPostsRow(
            momentId: UUID(),
            longitude: 0,
            latitude: 0,
            locationName: nil,
            momentDate: "2025-01-01T00:00:00Z",
            createdAt: nil,
            nearbyPosts: []
        )

        let cached = CachedMoment(from: row, cacheKey: "moments", sortOrder: 1)

        #expect(cached.toNearbyImagePosts().isEmpty)
        #expect(cached.decodedNearbyPosts().isEmpty)
    }

    @Test("CachedMoment with nil nearbyPostsData returns empty arrays")
    func momentNilPostsData() {
        let cached = CachedMoment(
            momentId: UUID(),
            cacheKey: "moments",
            sortOrder: 0,
            momentDate: "2025-01-01T00:00:00Z",
            locationName: "Nowhere",
            latitude: 0,
            longitude: 0,
            momentCreatedAt: "",
            nearbyPostsData: nil
        )

        #expect(cached.decodedNearbyPosts().isEmpty)
        #expect(cached.toNearbyImagePosts().isEmpty)
    }
}
