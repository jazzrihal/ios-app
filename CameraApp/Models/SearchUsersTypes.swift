import Foundation
import SwiftUI

// MARK: - search_users RPC Types

/// Parameters for the `search_users` Supabase RPC.
struct SearchUsersParams: Encodable, Sendable {
    let query: String
    let maxResults: Int

    enum CodingKeys: String, CodingKey {
        case query
        case maxResults = "max_results"
    }
}

/// Decoded row from the `search_users` Supabase RPC.
struct SearchUserRow: Decodable, Sendable {
    let id: UUID
    let username: String
    let displayName: String
    let bio: String?
    let gradientColors: [String]?
    let postCount: Int?
    let friendCount: Int?
    let similarityScore: Float

    enum CodingKeys: String, CodingKey {
        case id, username, bio
        case displayName = "display_name"
        case gradientColors = "gradient_colors"
        case postCount = "post_count"
        case friendCount = "friend_count"
        case similarityScore = "similarity_score"
    }
}

// MARK: - User init from SearchUserRow

extension User {
    /// Maps a `search_users` RPC row to the app's `User` model.
    init(from row: SearchUserRow) {
        id = row.id
        username = row.username
        displayName = row.displayName
        bio = row.bio ?? ""
        gradientColors = Self.parseGradientColors(row.gradientColors)
        joinDate = Date() // Not returned by search RPC
        postCount = row.postCount ?? 0
        friendCount = row.friendCount ?? 0
        mutualFriendCount = 0 // Not returned by search RPC
    }
}
