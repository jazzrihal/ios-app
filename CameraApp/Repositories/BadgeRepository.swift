import Foundation
import Observation

// MARK: - Protocol

@MainActor
protocol BadgeRepository {
    func fetchBadges(forPostId postId: UUID) async throws -> [PostBadge]
}

// MARK: - Implementation

@MainActor @Observable
final class DefaultBadgeRepository: BadgeRepository {
    func fetchBadges(forPostId postId: UUID) async throws -> [PostBadge] {
        let rows: [PostBadgeRow] = try await SupabaseManager.client
            .from("user_badges")
            .select("id, badge_type, metadata")
            .eq("post_id", value: postId)
            .execute()
            .value
        return rows.compactMap { $0.toPostBadge() }
    }
}
