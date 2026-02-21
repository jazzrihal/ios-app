import Foundation
import SwiftData

@Model
final class CachedMoment {
    var momentId: UUID
    var cacheKey: String
    var cachedAt: Date
    var sortOrder: Int

    var momentDate: String
    var locationName: String
    var latitude: Double
    var longitude: Double
    var momentCreatedAt: String

    /// Nearby posts stored as JSON-encoded array of NearbyPostRow
    var nearbyPostsData: Data?

    init(
        momentId: UUID,
        cacheKey: String,
        cachedAt: Date = Date(),
        sortOrder: Int = 0,
        momentDate: String,
        locationName: String,
        latitude: Double,
        longitude: Double,
        momentCreatedAt: String,
        nearbyPostsData: Data? = nil
    ) {
        self.momentId = momentId
        self.cacheKey = cacheKey
        self.cachedAt = cachedAt
        self.sortOrder = sortOrder
        self.momentDate = momentDate
        self.locationName = locationName
        self.latitude = latitude
        self.longitude = longitude
        self.momentCreatedAt = momentCreatedAt
        self.nearbyPostsData = nearbyPostsData
    }
}

// MARK: - Conversion Helpers

extension CachedMoment {
    convenience init(from row: MomentWithNearbyPostsRow, cacheKey: String, sortOrder: Int) {
        let postsData = try? JSONEncoder().encode(row.nearbyPosts)
        self.init(
            momentId: row.momentId,
            cacheKey: cacheKey,
            sortOrder: sortOrder,
            momentDate: row.momentDate,
            locationName: row.locationName ?? "",
            latitude: row.latitude,
            longitude: row.longitude,
            momentCreatedAt: row.createdAt ?? "",
            nearbyPostsData: postsData
        )
    }

    func toMoment() -> Moment {
        Moment(from: MomentWithNearbyPostsRow(
            momentId: momentId,
            longitude: longitude,
            latitude: latitude,
            locationName: locationName.isEmpty ? nil : locationName,
            momentDate: momentDate,
            createdAt: momentCreatedAt.isEmpty ? nil : momentCreatedAt,
            nearbyPosts: decodedNearbyPosts()
        ))
    }

    func decodedNearbyPosts() -> [NearbyPostRow] {
        guard let data = nearbyPostsData else { return [] }
        return (try? JSONDecoder().decode([NearbyPostRow].self, from: data)) ?? []
    }

    func toNearbyImagePosts() -> [ImagePost] {
        decodedNearbyPosts().map { ImagePost(from: $0) }
    }
}
