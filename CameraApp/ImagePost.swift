import Foundation
import CoreLocation
import SwiftUI

struct ImagePost: Identifiable {
    let id = UUID()
    let imageURL: URL
    let user: User
    let caption: String
    let coordinate: CLLocationCoordinate2D
    let locationName: String
    let timestamp: Date
    let distanceMeters: Double

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

        let label: String
        if absDiff < 60 {
            label = "at query time"
            return label
        } else if absDiff < 3600 {
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

            return ImagePost(
                imageURL: url,
                user: users[i],
                caption: captions[i],
                coordinate: postCoord,
                locationName: locationNames[i],
                timestamp: postDate,
                distanceMeters: distance
            )
        }
        .sorted { $0.distanceMeters < $1.distanceMeters }
    }
}
