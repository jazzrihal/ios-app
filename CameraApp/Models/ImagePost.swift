import CoreLocation
import Foundation
import SwiftUI

struct ImagePost: Identifiable {
    let id: UUID
    let imageURL: URL
    let user: User
    let caption: String
    let coordinate: CLLocationCoordinate2D
    let locationName: String
    let timestamp: Date
    let distanceMeters: Double
    let scope: PostScope
    var isPinned: Bool = false
    var isOwn: Bool = false

    var username: String {
        user.username
    }

    var distanceFormatted: String {
        if distanceMeters < 1000 {
            String(format: "%.0f m away", distanceMeters)
        } else {
            String(format: "%.1f km away", distanceMeters / 1000)
        }
    }

    var timeAgoFormatted: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: timestamp, relativeTo: .now)
    }

    func offsetFromQuery(_ queryDate: Date) -> String {
        let diff = timestamp.timeIntervalSince(queryDate)
        let absDiff = abs(diff)

        if absDiff < 60 {
            return "at query time"
        }

        let label: String
        if absDiff < 3600 {
            let mins = Int(absDiff / 60)
            label = "\(mins) min"
        } else if absDiff < 86400 {
            let hrs = Int(absDiff / 3600)
            let mins = Int((absDiff.truncatingRemainder(dividingBy: 3600)) / 60)
            label = mins > 0 ? "\(hrs) hr \(mins) min" : "\(hrs) hr"
        } else {
            let days = Int(absDiff / 86400)
            let hrs = Int((absDiff.truncatingRemainder(dividingBy: 86400)) / 3600)
            label = hrs > 0 ? "\(days) d \(hrs) hr" : "\(days) d"
        }

        return diff < 0 ? "\(label) before search time" : "\(label) after search time"
    }
}

// MARK: - nearby_posts RPC Types

/// Parameters for the `nearby_posts` Supabase RPC.
struct NearbyPostsParams: Encodable, Sendable {
    let lng: Double
    let lat: Double
    let searchDate: String
    let radiusMeters: Double
    var pageSize: Int?
    var pageOffset: Int?

    enum CodingKeys: String, CodingKey {
        case lng, lat
        case searchDate = "search_date"
        case radiusMeters = "radius_meters"
        case pageSize = "page_size"
        case pageOffset = "page_offset"
    }
}

/// Decoded row from the `nearby_posts` Supabase RPC.
struct NearbyPostRow: Codable {
    let id: UUID
    let userId: UUID
    let username: String
    let displayName: String
    let gradientColors: [String]?
    let imagePath: String
    let caption: String?
    let longitude: Double
    let latitude: Double
    let locationName: String?
    let scope: String
    let createdAt: String
    let distanceMeters: Double
    let totalCount: Int?

    enum CodingKeys: String, CodingKey {
        case id, username, caption, longitude, latitude, scope
        case userId = "user_id"
        case displayName = "display_name"
        case gradientColors = "gradient_colors"
        case imagePath = "image_path"
        case locationName = "location_name"
        case createdAt = "created_at"
        case distanceMeters = "distance_meters"
        case totalCount = "total_count"
    }
}

// MARK: - get_user_posts_and_pins RPC Types

/// Parameters for the `get_user_posts_and_pins` Supabase RPC.
struct GetUserPostsAndPinsParams: Encodable, Sendable {
    let targetUserId: UUID
    let pageSize: Int
    let pageOffset: Int

    enum CodingKeys: String, CodingKey {
        case targetUserId = "target_user_id"
        case pageSize = "page_size"
        case pageOffset = "page_offset"
    }
}

/// Decoded row from the `get_user_posts_and_pins` Supabase RPC.
struct UserPostWithPinRow: Codable {
    let id: UUID
    let userId: UUID
    let username: String
    let displayName: String
    let gradientColors: [String]?
    let imagePath: String
    let caption: String?
    let longitude: Double
    let latitude: Double
    let locationName: String?
    let scope: String
    let createdAt: String
    let isOwn: Bool
    let isPinned: Bool
    let totalCount: Int

    enum CodingKeys: String, CodingKey {
        case id, username, caption, longitude, latitude, scope
        case userId = "user_id"
        case displayName = "display_name"
        case gradientColors = "gradient_colors"
        case imagePath = "image_path"
        case locationName = "location_name"
        case createdAt = "created_at"
        case isOwn = "is_own"
        case isPinned = "is_pinned"
        case totalCount = "total_count"
    }
}

extension ImagePost {
    /// Creates an `ImagePost` from a `UserPostWithPinRow` returned by the RPC.
    init(from row: UserPostWithPinRow) {
        id = row.id
        imageURL = SupabaseManager.imageURL(for: row.imagePath)
        user = User(
            id: row.userId,
            username: row.username,
            displayName: row.displayName,
            bio: "",
            gradientColors: User.parseGradientColors(row.gradientColors),
            joinDate: Date(),
            postCount: 0,
            friendCount: 0,
            mutualFriendCount: 0
        )
        caption = row.caption ?? ""
        coordinate = CLLocationCoordinate2D(latitude: row.latitude, longitude: row.longitude)
        locationName = row.locationName ?? ""
        timestamp = Self.parseISO8601(row.createdAt) ?? Date()
        distanceMeters = 0
        scope = PostScope(serverValue: row.scope)
        isPinned = row.isPinned
        isOwn = row.isOwn
    }
}

extension ImagePost {
    /// Creates an `ImagePost` from a `NearbyPostRow` returned by the RPC.
    init(from row: NearbyPostRow) {
        id = row.id
        imageURL = SupabaseManager.imageURL(for: row.imagePath)
        user = User(
            id: row.userId,
            username: row.username,
            displayName: row.displayName,
            bio: "",
            gradientColors: User.parseGradientColors(row.gradientColors),
            joinDate: Date(),
            postCount: 0,
            friendCount: 0,
            mutualFriendCount: 0
        )
        caption = row.caption ?? ""
        coordinate = CLLocationCoordinate2D(latitude: row.latitude, longitude: row.longitude)
        locationName = row.locationName ?? ""
        timestamp = Self.parseISO8601(row.createdAt) ?? Date()
        distanceMeters = row.distanceMeters
        scope = PostScope(serverValue: row.scope)
    }

    /// Creates an `ImagePost` from a `PostsSelect` row + an owning `User`.
    init(from post: PublicSchema.PostsSelect, user: User) {
        id = post.id
        imageURL = SupabaseManager.imageURL(for: post.imagePath)
        self.user = user
        caption = post.caption ?? ""
        coordinate = CLLocationCoordinate2D(
            latitude: post.latitude,
            longitude: post.longitude
        )
        locationName = post.locationName ?? ""
        timestamp = Self.parseISO8601(post.createdAt) ?? Date()
        distanceMeters = 0
        scope = PostScope(serverValue: post.scope)
    }

    private static func parseISO8601(_ string: String?) -> Date? {
        ISO8601DateFormatter.flexibleParse(string)
    }
}

// MARK: - Shared ISO 8601 Helper

extension ISO8601DateFormatter {
    /// Parses an ISO 8601 string, trying fractional-seconds first, then plain.
    static func flexibleParse(_ string: String?) -> Date? {
        guard let string else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: string) ?? ISO8601DateFormatter().date(from: string)
    }
}

// MARK: - Sample Data

extension ImagePost {
    /// Users that match the sample post usernames.
    /// The first 5 correspond to `User.sampleFriends()`, the next 5 to `User.sampleSuggested()`.
    private static func samplePostUsers() -> [User] {
        let friends = User.sampleFriends() // alex_photo, wanderlust99, cityshots, nature_lens, pixel_hunter
        let suggested = User.sampleSuggested() // golden_hour, street_vibes, mountain_soul, ocean_dreamer, urban_eye, ...
        return friends + Array(suggested.prefix(5))
    }

    static func samplePosts(near coordinate: CLLocationCoordinate2D, around date: Date) -> [ImagePost] {
        let users = samplePostUsers()
        let captions = [
            "Golden hour at its finest ✨",
            "Found this hidden gem today",
            "The light was perfect this morning",
            "Can't believe this place exists",
            "Weekend adventures 🌿",
            "Chasing sunsets again",
            "A quiet moment in the city",
            "Nature always wins",
            "Lost in the beauty of this spot",
            "Early bird gets the shot 📸",
        ]
        let locationNames = [
            "Mission District, San Francisco",
            "Haight-Ashbury, San Francisco",
            "Marina District, San Francisco",
            "Golden Gate Park, San Francisco",
            "SoMa, San Francisco",
            "North Beach, San Francisco",
            "Castro, San Francisco",
            "Noe Valley, San Francisco",
            "Sunset District, San Francisco",
            "Presidio, San Francisco",
        ]

        return (0 ..< 10).map { i in
            let latOffset = Double.random(in: -0.02 ... 0.02)
            let lonOffset = Double.random(in: -0.02 ... 0.02)
            let postCoord = CLLocationCoordinate2D(
                latitude: coordinate.latitude + latOffset,
                longitude: coordinate.longitude + lonOffset
            )

            let loc1 = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let loc2 = CLLocation(latitude: postCoord.latitude, longitude: postCoord.longitude)
            let distance = loc1.distance(from: loc2)

            let hoursOffset = Double.random(in: -12 ... 0)
            let postDate = date.addingTimeInterval(hoursOffset * 3600)

            let imageId = (i + 1) * 10 + Int.random(in: 0 ... 9)
            let url = URL(string: "https://picsum.photos/id/\(imageId)/400/400")!

            let scope: PostScope = Bool.random() ? .public : .friends

            return ImagePost(
                id: UUID(),
                imageURL: url,
                user: users[i],
                caption: captions[i],
                coordinate: postCoord,
                locationName: locationNames[i],
                timestamp: postDate,
                distanceMeters: distance,
                scope: scope
            )
        }
        .sorted { $0.distanceMeters < $1.distanceMeters }
    }

    /// Simulates a server response that returns only the posts the viewer is allowed to see.
    /// - Parameters:
    ///   - user: The profile owner whose posts to fetch.
    ///   - isFriend: Whether the viewer is friends with the profile owner.
    /// - Returns: Posts filtered server-side by scope (public only for non-friends, public + friends for friends).
    static func sampleUserPosts(for user: User, isFriend: Bool) -> [ImagePost] {
        let captions = [
            "Golden hour at its finest ✨",
            "Found this hidden gem today",
            "The light was perfect this morning",
            "Can't believe this place exists",
            "Weekend adventures 🌿",
            "Chasing sunsets again",
            "A quiet moment in the city",
            "Nature always wins",
            "Lost in the beauty of this spot",
        ]
        let locationNames = [
            "Mission District, San Francisco",
            "Haight-Ashbury, San Francisco",
            "Marina District, San Francisco",
            "Golden Gate Park, San Francisco",
            "SoMa, San Francisco",
            "North Beach, San Francisco",
            "Castro, San Francisco",
            "Noe Valley, San Francisco",
            "Sunset District, San Francisco",
        ]

        // Generate all posts for this user (server knows all of them)
        let allPosts: [ImagePost] = (0 ..< 9).map { i in
            let baseLat = 37.7749 + Double(i) * 0.003
            let baseLon = -122.4194 + Double(i) * 0.002
            let coord = CLLocationCoordinate2D(latitude: baseLat, longitude: baseLon)

            let daysAgo = Double(i * 3 + 1)
            let postDate = Date().addingTimeInterval(-daysAgo * 86400)

            let imageId = 100 + (user.username.hashValue & 0xFF) + i * 7
            let absId = abs(imageId) % 300 + 10
            let url = URL(string: "https://picsum.photos/id/\(absId)/400/400")!

            // Alternate scopes: roughly 1/3 public, 2/3 friends-only
            let scope: PostScope = (i % 3 == 0) ? .public : .friends

            return ImagePost(
                id: UUID(),
                imageURL: url,
                user: user,
                caption: captions[i],
                coordinate: coord,
                locationName: locationNames[i],
                timestamp: postDate,
                distanceMeters: Double(i) * 250 + 100,
                scope: scope
            )
        }

        // Server-side filtering: only return posts the viewer is authorized to see
        if isFriend {
            return allPosts.filter { $0.scope == .public || $0.scope == .friends }
        } else {
            return allPosts.filter { $0.scope == .public }
        }
    }
}
