import Foundation
import Supabase
import SwiftUI

// MARK: - Notification Type

enum NotificationType: String, Codable {
    case friendRequestReceived = "friend_request_received"
    case friendRequestAccepted = "friend_request_accepted"
    case postLiked = "post_liked"
    case badgeAwarded = "badge_awarded"
}

// MARK: - Domain Model

struct AppNotification: Identifiable {
    let id: UUID
    let type: NotificationType
    let actorId: UUID
    let actorUsername: String
    let actorDisplayName: String
    let actorGradientColors: [Color]
    let entityId: UUID?
    let createdAt: Date
    var isRead: Bool

    let badgeType: String?
    let badgeName: String?
}

// MARK: - RPC Param & Row Types

/// Parameters for the `get_notifications` Supabase RPC.
struct GetNotificationsParams: Encodable {
    let pageSize: Int
    let pageOffset: Int

    enum CodingKeys: String, CodingKey {
        case pageSize = "page_size"
        case pageOffset = "page_offset"
    }
}

/// Decoded row from the `get_notifications` Supabase RPC.
struct GetNotificationsRow: Decodable {
    let notificationId: UUID
    let type: String
    let actorId: UUID
    let actorUsername: String
    let actorDisplayName: String?
    let actorGradientColors: [String]?
    let entityId: UUID?
    let createdAt: String
    /// Null means unread; a timestamp means the notification was read at that time.
    let readAt: String?
    let metadata: AnyJSON?

    enum CodingKeys: String, CodingKey {
        case notificationId = "id"
        case type
        case actorId = "actor_id"
        case actorUsername = "actor_username"
        case actorDisplayName = "actor_display_name"
        case actorGradientColors = "actor_gradient_colors"
        case entityId = "entity_id"
        case createdAt = "created_at"
        case readAt = "read_at"
        case metadata
    }

    func toAppNotification() -> AppNotification? {
        guard let notifType = NotificationType(rawValue: type) else { return nil }

        var badgeType: String?
        var badgeName: String?
        if notifType == .badgeAwarded, let metadata {
            badgeType = metadata.stringValue(forKey: "badge_type")
            badgeName = metadata.stringValue(forKey: "badge_name")
        }

        return AppNotification(
            id: notificationId,
            type: notifType,
            actorId: actorId,
            actorUsername: actorUsername,
            actorDisplayName: actorDisplayName ?? actorUsername,
            actorGradientColors: User.parseGradientColors(actorGradientColors),
            entityId: entityId,
            createdAt: parseDate(createdAt) ?? Date(),
            isRead: readAt != nil,
            badgeType: badgeType,
            badgeName: badgeName
        )
    }

    private func parseDate(_ iso: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: iso) ?? ISO8601DateFormatter().date(from: iso)
    }
}

/// Parameters for the `mark_notification_read` Supabase RPC.
struct MarkNotificationReadParams: Encodable {
    let notificationId: UUID

    enum CodingKeys: String, CodingKey {
        case notificationId = "notification_id"
    }
}
