import Foundation
import SwiftUI

// MARK: - Friend Status

enum FriendStatus: Equatable {
    case none
    case pendingSent // You sent them a request
    case pendingReceived // They sent you a request
    case friends
}

// MARK: - User

struct User: Identifiable, Equatable {
    let id: UUID
    let username: String
    let displayName: String
    let bio: String
    let gradientColors: [Color]
    let joinDate: Date
    let postCount: Int
    let friendCount: Int
    let mutualFriendCount: Int

    var initials: String {
        let parts = displayName.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(displayName.prefix(2)).uppercased()
    }

    var joinDateFormatted: String {
        joinDate.formatted(.dateTime.month(.wide).year())
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Sample Data

extension User {
    static let currentUser = User(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        username: "me",
        displayName: "You",
        bio: "This is you!",
        gradientColors: [.blue, .purple],
        joinDate: Calendar.current.date(byAdding: .month, value: -8, to: Date())!,
        postCount: 24,
        friendCount: 12,
        mutualFriendCount: 0
    )

    private static let allGradients: [[Color]] = [
        [.blue, .cyan],
        [.purple, .pink],
        [.orange, .red],
        [.green, .mint],
        [.indigo, .blue],
        [.pink, .orange],
        [.teal, .green],
        [.red, .purple],
        [.cyan, .indigo],
        [.mint, .teal],
        [.yellow, .orange],
        [.brown, .orange],
    ]

    static func sampleFriends() -> [User] {
        let now = Date()
        return [
            User(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!,
                username: "alex_photo",
                displayName: "Alex Rivera",
                bio: "Photographer & traveler. Capturing moments one shot at a time.",
                gradientColors: allGradients[0],
                joinDate: Calendar.current.date(byAdding: .month, value: -14, to: now)!,
                postCount: 87,
                friendCount: 34,
                mutualFriendCount: 5
            ),
            User(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000011")!,
                username: "wanderlust99",
                displayName: "Maya Chen",
                bio: "Digital nomad. Currently somewhere beautiful.",
                gradientColors: allGradients[1],
                joinDate: Calendar.current.date(byAdding: .month, value: -10, to: now)!,
                postCount: 142,
                friendCount: 78,
                mutualFriendCount: 3
            ),
            User(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000012")!,
                username: "cityshots",
                displayName: "Jordan Park",
                bio: "Urban explorer. Finding beauty in concrete jungles.",
                gradientColors: allGradients[2],
                joinDate: Calendar.current.date(byAdding: .month, value: -6, to: now)!,
                postCount: 53,
                friendCount: 21,
                mutualFriendCount: 8
            ),
            User(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000013")!,
                username: "nature_lens",
                displayName: "Sam Okafor",
                bio: "Nature & wildlife. Early mornings, golden light.",
                gradientColors: allGradients[3],
                joinDate: Calendar.current.date(byAdding: .month, value: -18, to: now)!,
                postCount: 201,
                friendCount: 92,
                mutualFriendCount: 2
            ),
            User(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000014")!,
                username: "pixel_hunter",
                displayName: "Lena Kowalski",
                bio: "Street photography addict. Coffee enthusiast.",
                gradientColors: allGradients[4],
                joinDate: Calendar.current.date(byAdding: .month, value: -4, to: now)!,
                postCount: 38,
                friendCount: 15,
                mutualFriendCount: 6
            ),
        ]
    }

    static func sampleSuggested() -> [User] {
        let now = Date()
        return [
            User(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000020")!,
                username: "golden_hour",
                displayName: "Kai Tanaka",
                bio: "Chasing golden hours around the world.",
                gradientColors: allGradients[5],
                joinDate: Calendar.current.date(byAdding: .month, value: -9, to: now)!,
                postCount: 64,
                friendCount: 42,
                mutualFriendCount: 4
            ),
            User(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000021")!,
                username: "street_vibes",
                displayName: "Amara Johnson",
                bio: "Street art & culture. Always exploring.",
                gradientColors: allGradients[6],
                joinDate: Calendar.current.date(byAdding: .month, value: -12, to: now)!,
                postCount: 118,
                friendCount: 67,
                mutualFriendCount: 7
            ),
            User(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000022")!,
                username: "mountain_soul",
                displayName: "Erik Olsen",
                bio: "Mountain life. Hiking, climbing, and photographing peaks.",
                gradientColors: allGradients[7],
                joinDate: Calendar.current.date(byAdding: .month, value: -20, to: now)!,
                postCount: 176,
                friendCount: 53,
                mutualFriendCount: 1
            ),
            User(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000023")!,
                username: "ocean_dreamer",
                displayName: "Isla Moreno",
                bio: "Salt water heals everything. Surf & photo.",
                gradientColors: allGradients[8],
                joinDate: Calendar.current.date(byAdding: .month, value: -7, to: now)!,
                postCount: 91,
                friendCount: 38,
                mutualFriendCount: 3
            ),
            User(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000024")!,
                username: "urban_eye",
                displayName: "Dex Williams",
                bio: "Architecture & design in every city.",
                gradientColors: allGradients[9],
                joinDate: Calendar.current.date(byAdding: .month, value: -15, to: now)!,
                postCount: 134,
                friendCount: 71,
                mutualFriendCount: 5
            ),
            User(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000025")!,
                username: "lightcatcher",
                displayName: "Sofia Petrov",
                bio: "Film & digital. Capturing life's quiet moments.",
                gradientColors: allGradients[10],
                joinDate: Calendar.current.date(byAdding: .month, value: -3, to: now)!,
                postCount: 29,
                friendCount: 18,
                mutualFriendCount: 2
            ),
            User(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000026")!,
                username: "rooftop_views",
                displayName: "Marcus Lee",
                bio: "Rooftop photographer. Cities from above.",
                gradientColors: allGradients[11],
                joinDate: Calendar.current.date(byAdding: .month, value: -11, to: now)!,
                postCount: 82,
                friendCount: 44,
                mutualFriendCount: 6
            ),
        ]
    }

    static func sampleIncomingRequests() -> [User] {
        let now = Date()
        return [
            User(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000030")!,
                username: "sunset_chaser",
                displayName: "Nina Rossi",
                bio: "Every sunset is a new beginning.",
                gradientColors: allGradients[1],
                joinDate: Calendar.current.date(byAdding: .month, value: -5, to: now)!,
                postCount: 47,
                friendCount: 28,
                mutualFriendCount: 3
            ),
            User(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000031")!,
                username: "fog_city",
                displayName: "Theo Nakamura",
                bio: "SF fog and Victorian architecture.",
                gradientColors: allGradients[8],
                joinDate: Calendar.current.date(byAdding: .month, value: -8, to: now)!,
                postCount: 66,
                friendCount: 35,
                mutualFriendCount: 5
            ),
        ]
    }
}
