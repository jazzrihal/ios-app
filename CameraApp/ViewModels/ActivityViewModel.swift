import Observation
import SwiftUI

@Observable
final class ActivityViewModel {
    // MARK: - State

    private(set) var notifications: [AppNotification] = []
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var hasMorePages = true
    private(set) var unreadCount: Int = 0
    var error: String?

    // MARK: - Repository

    var repository: (any NotificationRepository)?

    private let pageSize = 20

    // MARK: - Load

    @MainActor
    func load() async {
        guard let repository else { return }
        isLoading = true
        error = nil
        do {
            async let notifs = repository.fetchNotifications(pageSize: pageSize, pageOffset: 0)
            async let count = repository.getUnreadCount()
            notifications = try await notifs
            unreadCount = try await count
            hasMorePages = notifications.count == pageSize
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Load More

    @MainActor
    func loadMore() async {
        guard let repository, hasMorePages, !isLoadingMore else { return }
        isLoadingMore = true
        do {
            let newNotifs = try await repository.fetchNotifications(
                pageSize: pageSize,
                pageOffset: notifications.count
            )
            notifications.append(contentsOf: newNotifs)
            hasMorePages = newNotifs.count == pageSize
        } catch {
            self.error = error.localizedDescription
        }
        isLoadingMore = false
    }

    // MARK: - Refresh

    @MainActor
    func refresh() async {
        guard let repository else { return }
        do {
            async let notifs = repository.fetchNotifications(pageSize: pageSize, pageOffset: 0)
            async let count = repository.getUnreadCount()
            notifications = try await notifs
            unreadCount = try await count
            hasMorePages = notifications.count == pageSize
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Mark Read

    func markRead(id: UUID) {
        guard let idx = notifications.firstIndex(where: { $0.id == id }),
              !notifications[idx].isRead else { return }
        notifications[idx].isRead = true
        unreadCount = max(0, unreadCount - 1)
        Task { try? await repository?.markRead(id: id) }
    }

    func markAllRead() {
        for idx in notifications.indices {
            notifications[idx].isRead = true
        }
        unreadCount = 0
        Task { try? await repository?.markAllRead() }
    }
}
