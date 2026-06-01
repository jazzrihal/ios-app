import Foundation
import Observation
import OSLog
import Supabase

@MainActor @Observable
final class FriendRealtimeService {
    private var channel: RealtimeChannelV2?
    private var listenerTask: Task<Void, Never>?
    private var debounceTask: Task<Void, Never>?
    private var activeUserId: UUID?
    private var refreshHandler: (@MainActor () async -> Void)?
    private(set) var lastError: String?
    private let logger = Logger(subsystem: "com.jazzrihal.pinstoria", category: "FriendRealtime")

    private let debounceDelay = Duration.milliseconds(400)
    private let maxSubscribeAttempts = 4
    private let initialSubscribeRetryDelayNs: UInt64 = 300_000_000
    private let maxSubscribeRetryDelayNs: UInt64 = 2_400_000_000

    func start(userId: UUID, onRefresh: @escaping @MainActor () async -> Void) async {
        lastError = nil

        if activeUserId == userId, channel != nil {
            refreshHandler = onRefresh
            return
        }

        await stop()
        refreshHandler = onRefresh
        activeUserId = userId

        let channel = SupabaseManager.client.channel("friendships-\(userId.uuidString)")
        self.channel = channel

        let userIdString = userId.uuidString.lowercased()

        let requesterEvents = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "friendships",
            filter: .eq("requester_id", value: userIdString)
        )

        let addresseeEvents = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "friendships",
            filter: .eq("addressee_id", value: userIdString)
        )

        listenerTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await subscribeWithRetry(channel: channel, userId: userId)
            } catch is CancellationError {
                return
            } catch {
                let message = "Failed to subscribe to realtime for user \(userId): \(error)"
                lastError = message
                logger.error("Failed to subscribe to realtime: \(message, privacy: .private)")
                return
            }

            await withTaskGroup(of: Void.self) { group in
                group.addTask { [weak self] in
                    guard let self else { return }
                    for await _ in requesterEvents {
                        await scheduleDebouncedRefresh()
                    }
                }

                group.addTask { [weak self] in
                    guard let self else { return }
                    for await _ in addresseeEvents {
                        await scheduleDebouncedRefresh()
                    }
                }

                await group.waitForAll()
            }
        }
    }

    func stop() async {
        listenerTask?.cancel()
        listenerTask = nil

        debounceTask?.cancel()
        debounceTask = nil

        if let channel {
            await SupabaseManager.client.removeChannel(channel)
        }

        channel = nil
        activeUserId = nil
        refreshHandler = nil
    }

    private func scheduleDebouncedRefresh() {
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            do {
                try await Task.sleep(for: self?.debounceDelay ?? .zero)
            } catch {
                return
            }

            guard let self, !Task.isCancelled else { return }
            await refreshHandler?()
        }
    }

    private func subscribeWithRetry(channel: RealtimeChannelV2, userId: UUID) async throws {
        var delayNs = initialSubscribeRetryDelayNs

        for attempt in 1 ... maxSubscribeAttempts {
            do {
                try await channel.subscribeWithError()
                lastError = nil
                return
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                let message =
                    "Subscribe attempt \(attempt)/\(maxSubscribeAttempts) failed for user \(userId): \(error)"
                lastError = message
                logger.error("Realtime subscribe attempt failed: \(message, privacy: .private)")

                guard attempt < maxSubscribeAttempts else { throw error }
                try await Task.sleep(nanoseconds: delayNs)
                delayNs = min(delayNs * 2, maxSubscribeRetryDelayNs)
            }
        }
    }
}
