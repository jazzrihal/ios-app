import CoreLocation
import Foundation

// MARK: - moments_with_nearby_posts RPC Types

/// Parameters for the `moments_with_nearby_posts` Supabase RPC.
struct MomentsWithNearbyPostsParams: Encodable, Sendable {
    let radiusMeters: Double?
    let dateRangeDays: Int?
    let timeDecayHours: Double?
    let distanceWeight: Double?
    let postsPerMoment: Int?

    enum CodingKeys: String, CodingKey {
        case radiusMeters = "radius_meters"
        case dateRangeDays = "date_range_days"
        case timeDecayHours = "time_decay_hours"
        case distanceWeight = "distance_weight"
        case postsPerMoment = "posts_per_moment"
    }
}

/// Decoded row from the `moments_with_nearby_posts` Supabase RPC.
struct MomentWithNearbyPostsRow: Decodable, Sendable {
    let momentId: UUID
    let longitude: Double
    let latitude: Double
    let locationName: String?
    let momentDate: String
    let createdAt: String?
    let nearbyPosts: [NearbyPostRow]

    enum CodingKeys: String, CodingKey {
        case longitude, latitude
        case momentId = "moment_id"
        case locationName = "location_name"
        case momentDate = "moment_date"
        case createdAt = "created_at"
        case nearbyPosts = "nearby_posts"
    }
}

// MARK: - Moment init from MomentWithNearbyPostsRow

extension Moment {
    /// Creates a `Moment` from a `moments_with_nearby_posts` RPC row.
    init(from row: MomentWithNearbyPostsRow) {
        id = row.momentId
        date = ISO8601DateFormatter.flexibleParse(row.momentDate) ?? Date()
        locationName = row.locationName ?? ""
        coordinate = CLLocationCoordinate2D(
            latitude: row.latitude,
            longitude: row.longitude
        )
        addedAt = ISO8601DateFormatter.flexibleParse(row.createdAt) ?? Date()
    }
}
