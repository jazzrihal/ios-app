@testable import CameraApp
import Foundation
import Supabase
import Testing

// MARK: - PostBadge Display Properties

@Suite("PostBadge display properties")
struct PostBadgeDisplayTests {
    @Test("first_post badge returns star icon and yellow color")
    func firstPostBadge() {
        let badge = PostBadge(
            id: UUID(),
            badgeType: "first_post",
            badgeName: "First Post",
            badgeDescription: "You made your first post!"
        )
        #expect(badge.displayIcon == "star.fill")
        #expect(badge.displayColor == .yellow)
    }

    @Test("location_discoverer badge returns map icon and teal color")
    func locationDiscovererBadge() {
        let badge = PostBadge(
            id: UUID(),
            badgeType: "location_discoverer",
            badgeName: "Location Discoverer",
            badgeDescription: "First to post from this location"
        )
        #expect(badge.displayIcon == "mappin.and.ellipse")
        #expect(badge.displayColor == .teal)
    }

    @Test("first_among_friends badge returns people icon and purple color")
    func firstAmongFriendsBadge() {
        let badge = PostBadge(
            id: UUID(),
            badgeType: "first_among_friends",
            badgeName: "First Among Friends",
            badgeDescription: "First of your friends to post today"
        )
        #expect(badge.displayIcon == "person.2.fill")
        #expect(badge.displayColor == .purple)
    }

    @Test("Unknown badge type returns medal icon and secondary color")
    func unknownBadge() {
        let badge = PostBadge(
            id: UUID(),
            badgeType: "some_future_type",
            badgeName: "Mystery",
            badgeDescription: "Unknown"
        )
        #expect(badge.displayIcon == "medal.fill")
        #expect(badge.displayColor == .secondary)
    }
}

// MARK: - PostBadgeRow Conversion

@Suite("PostBadgeRow to PostBadge conversion")
struct PostBadgeRowConversionTests {
    @Test("Valid metadata converts to PostBadge")
    func validMetadata() {
        let row = PostBadgeRow(
            id: UUID(),
            badgeType: "first_post",
            metadata: .object([
                "badge_name": .string("First Post"),
                "badge_description": .string("You made your first post!"),
            ])
        )
        let badge = row.toPostBadge()
        #expect(badge != nil)
        #expect(badge?.badgeName == "First Post")
        #expect(badge?.badgeDescription == "You made your first post!")
        #expect(badge?.badgeType == "first_post")
    }

    @Test("Missing badge_name in metadata returns nil")
    func missingBadgeName() {
        let row = PostBadgeRow(
            id: UUID(),
            badgeType: "first_post",
            metadata: .object([
                "badge_description": .string("desc"),
            ])
        )
        #expect(row.toPostBadge() == nil)
    }

    @Test("Missing badge_description in metadata returns nil")
    func missingBadgeDescription() {
        let row = PostBadgeRow(
            id: UUID(),
            badgeType: "first_post",
            metadata: .object([
                "badge_name": .string("First Post"),
            ])
        )
        #expect(row.toPostBadge() == nil)
    }

    @Test("Non-object metadata returns nil")
    func nonObjectMetadata() {
        let row = PostBadgeRow(
            id: UUID(),
            badgeType: "first_post",
            metadata: .string("not an object")
        )
        #expect(row.toPostBadge() == nil)
    }
}

// MARK: - Badge Notification Parsing

@Suite("Badge notification parsing")
struct BadgeNotificationParsingTests {
    private func makeRow(
        type: String = "badge_awarded",
        metadata: AnyJSON? = nil
    ) -> GetNotificationsRow {
        GetNotificationsRow(
            notificationId: UUID(),
            type: type,
            actorId: UUID(),
            actorUsername: "testuser",
            actorDisplayName: "Test User",
            actorGradientColors: nil,
            entityId: nil,
            createdAt: "2026-03-15T10:00:00.000Z",
            readAt: nil,
            metadata: metadata
        )
    }

    @Test("badge_awarded notification parses badge_type and badge_name from metadata")
    func badgeAwardedWithMetadata() {
        let row = makeRow(metadata: .object([
            "badge_type": .string("first_post"),
            "badge_name": .string("First Post"),
            "badge_description": .string("You made your first post!"),
        ]))
        let notification = row.toAppNotification()
        #expect(notification != nil)
        #expect(notification?.type == .badgeAwarded)
        #expect(notification?.badgeType == "first_post")
        #expect(notification?.badgeName == "First Post")
    }

    @Test("badge_awarded with nil metadata has nil badge fields")
    func badgeAwardedWithoutMetadata() {
        let row = makeRow(metadata: nil)
        let notification = row.toAppNotification()
        #expect(notification != nil)
        #expect(notification?.type == .badgeAwarded)
        #expect(notification?.badgeType == nil)
        #expect(notification?.badgeName == nil)
    }

    @Test("Non-badge notification has nil badge fields")
    func nonBadgeNotification() {
        let row = makeRow(
            type: "post_liked",
            metadata: .object([
                "badge_type": .string("first_post"),
            ])
        )
        let notification = row.toAppNotification()
        #expect(notification != nil)
        #expect(notification?.type == .postLiked)
        #expect(notification?.badgeType == nil)
        #expect(notification?.badgeName == nil)
    }
}
