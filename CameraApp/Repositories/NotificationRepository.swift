import Foundation
import Observation

// MARK: - Protocol

@MainActor
protocol NotificationRepository {
    func fetchNotifications(pageSize: Int, pageOffset: Int) async throws -> [AppNotification]
    func markRead(id: UUID) async throws
    func markAllRead() async throws
    func getUnreadCount() async throws -> Int
}

// MARK: - Implementation

@MainActor @Observable
final class DefaultNotificationRepository: NotificationRepository {
    func fetchNotifications(pageSize: Int, pageOffset: Int) async throws -> [AppNotification] {
        let params = GetNotificationsParams(pageSize: pageSize, pageOffset: pageOffset)
        let rows: [GetNotificationsRow] = try await SupabaseManager.client
            .rpc("get_notifications", params: params)
            .execute()
            .value
        return rows.compactMap { $0.toAppNotification() }
    }

    func markRead(id: UUID) async throws {
        let params = MarkNotificationReadParams(notificationId: id)
        _ = try await SupabaseManager.client
            .rpc("mark_notification_read", params: params)
            .execute()
    }

    func markAllRead() async throws {
        _ = try await SupabaseManager.client
            .rpc("mark_all_notifications_read")
            .execute()
    }

    func getUnreadCount() async throws -> Int {
        try await SupabaseManager.client
            .rpc("get_unread_notification_count")
            .execute()
            .value
    }
}
