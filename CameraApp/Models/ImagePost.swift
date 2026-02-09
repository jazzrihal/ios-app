import Foundation
import CoreLocation

struct ImagePost: Identifiable {
    let id = UUID()
    let imageURL: URL
    let user: User
    let caption: String
    let coordinate: CLLocationCoordinate2D
    let locationName: String
    let timestamp: Date
    let distanceMeters: Double
    let scope: PostScope

    var username: String { user.username }

    var distanceFormatted: String {
        if distanceMeters < 1000 {
            return String(format: "%.0f m away", distanceMeters)
        } else {
            return String(format: "%.1f km away", distanceMeters / 1000)
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

// MARK: - Sample Data

extension ImagePost {
    /// Users that match the sample post usernames.
    /// The first 5 correspond to `User.sampleFriends()`, the next 5 to `User.sampleSuggested()`.
    private static func samplePostUsers() -> [User] {
        let friends = User.sampleFriends()   // alex_photo, wanderlust99, cityshots, nature_lens, pixel_hunter
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
            "Early bird gets the shot 📸"
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
            "Presidio, San Francisco"
        ]

        return (0..<10).map { i in
            let latOffset = Double.random(in: -0.02...0.02)
            let lonOffset = Double.random(in: -0.02...0.02)
            let postCoord = CLLocationCoordinate2D(
                latitude: coordinate.latitude + latOffset,
                longitude: coordinate.longitude + lonOffset
            )

            let loc1 = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let loc2 = CLLocation(latitude: postCoord.latitude, longitude: postCoord.longitude)
            let distance = loc1.distance(from: loc2)

            let hoursOffset = Double.random(in: -12...0)
            let postDate = date.addingTimeInterval(hoursOffset * 3600)

            let imageId = (i + 1) * 10 + Int.random(in: 0...9)
            let url = URL(string: "https://picsum.photos/id/\(imageId)/400/400")!

            let scope: PostScope = Bool.random() ? .public : .friends

            return ImagePost(
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
        let allPosts: [ImagePost] = (0..<9).map { i in
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
