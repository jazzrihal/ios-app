// Auto-generated Supabase types — do not edit manually.
// Regenerate with: supabase gen types swift

import Foundation
import Supabase

// MARK: - Schema Enums

enum GraphqlPublicSchema {}
enum PublicSchema {
    // MARK: - Device Tokens

    struct DeviceTokensSelect: Codable, Hashable, Sendable {
        let createdAt: String?
        let id: UUID
        let platform: String?
        let token: String
        let userId: UUID
        enum CodingKeys: String, CodingKey {
            case createdAt = "created_at"
            case id
            case platform
            case token
            case userId = "user_id"
        }
    }

    struct DeviceTokensInsert: Codable, Hashable, Sendable {
        let createdAt: String?
        let id: UUID?
        let platform: String?
        let token: String
        let userId: UUID
        enum CodingKeys: String, CodingKey {
            case createdAt = "created_at"
            case id
            case platform
            case token
            case userId = "user_id"
        }
    }

    struct DeviceTokensUpdate: Codable, Hashable, Sendable {
        let createdAt: String?
        let id: UUID?
        let platform: String?
        let token: String?
        let userId: UUID?
        enum CodingKeys: String, CodingKey {
            case createdAt = "created_at"
            case id
            case platform
            case token
            case userId = "user_id"
        }
    }

    // MARK: - Friendships

    struct FriendshipsSelect: Codable, Hashable, Sendable {
        let addresseeId: UUID
        let createdAt: String?
        let requesterId: UUID
        let status: String
        enum CodingKeys: String, CodingKey {
            case addresseeId = "addressee_id"
            case createdAt = "created_at"
            case requesterId = "requester_id"
            case status
        }
    }

    struct FriendshipsInsert: Codable, Hashable, Sendable {
        let addresseeId: UUID
        let createdAt: String?
        let requesterId: UUID
        let status: String?
        enum CodingKeys: String, CodingKey {
            case addresseeId = "addressee_id"
            case createdAt = "created_at"
            case requesterId = "requester_id"
            case status
        }
    }

    struct FriendshipsUpdate: Codable, Hashable, Sendable {
        let addresseeId: UUID?
        let createdAt: String?
        let requesterId: UUID?
        let status: String?
        enum CodingKeys: String, CodingKey {
            case addresseeId = "addressee_id"
            case createdAt = "created_at"
            case requesterId = "requester_id"
            case status
        }
    }

    // MARK: - Likes

    struct LikesSelect: Codable, Hashable, Sendable {
        let createdAt: String?
        let postId: UUID
        let userId: UUID
        enum CodingKeys: String, CodingKey {
            case createdAt = "created_at"
            case postId = "post_id"
            case userId = "user_id"
        }
    }

    struct LikesInsert: Codable, Hashable, Sendable {
        let createdAt: String?
        let postId: UUID
        let userId: UUID
        enum CodingKeys: String, CodingKey {
            case createdAt = "created_at"
            case postId = "post_id"
            case userId = "user_id"
        }
    }

    struct LikesUpdate: Codable, Hashable, Sendable {
        let createdAt: String?
        let postId: UUID?
        let userId: UUID?
        enum CodingKeys: String, CodingKey {
            case createdAt = "created_at"
            case postId = "post_id"
            case userId = "user_id"
        }
    }

    // MARK: - Moments

    struct MomentsSelect: Codable, Hashable, Sendable {
        let createdAt: String?
        let id: UUID
        let location: GeographySelect
        let locationName: String?
        let momentDate: String
        let userId: UUID
        enum CodingKeys: String, CodingKey {
            case createdAt = "created_at"
            case id
            case location
            case locationName = "location_name"
            case momentDate = "moment_date"
            case userId = "user_id"
        }
    }

    struct MomentsInsert: Codable, Hashable, Sendable {
        let createdAt: String?
        let id: UUID?
        let location: GeographySelect
        let locationName: String?
        let momentDate: String
        let userId: UUID
        enum CodingKeys: String, CodingKey {
            case createdAt = "created_at"
            case id
            case location
            case locationName = "location_name"
            case momentDate = "moment_date"
            case userId = "user_id"
        }
    }

    struct MomentsUpdate: Codable, Hashable, Sendable {
        let createdAt: String?
        let id: UUID?
        let location: GeographySelect?
        let locationName: String?
        let momentDate: String?
        let userId: UUID?
        enum CodingKeys: String, CodingKey {
            case createdAt = "created_at"
            case id
            case location
            case locationName = "location_name"
            case momentDate = "moment_date"
            case userId = "user_id"
        }
    }

    // MARK: - Pins

    struct PinsSelect: Codable, Hashable, Sendable {
        let createdAt: String?
        let postId: UUID
        let userId: UUID
        enum CodingKeys: String, CodingKey {
            case createdAt = "created_at"
            case postId = "post_id"
            case userId = "user_id"
        }
    }

    struct PinsInsert: Codable, Hashable, Sendable {
        let createdAt: String?
        let postId: UUID
        let userId: UUID
        enum CodingKeys: String, CodingKey {
            case createdAt = "created_at"
            case postId = "post_id"
            case userId = "user_id"
        }
    }

    struct PinsUpdate: Codable, Hashable, Sendable {
        let createdAt: String?
        let postId: UUID?
        let userId: UUID?
        enum CodingKeys: String, CodingKey {
            case createdAt = "created_at"
            case postId = "post_id"
            case userId = "user_id"
        }
    }

    // MARK: - Posts

    struct PostsSelect: Codable, Hashable, Sendable {
        let caption: String?
        let createdAt: String?
        let id: UUID
        let imagePath: String
        let location: GeographySelect
        let locationName: String?
        let scope: String
        let userId: UUID
        enum CodingKeys: String, CodingKey {
            case caption
            case createdAt = "created_at"
            case id
            case imagePath = "image_path"
            case location
            case locationName = "location_name"
            case scope
            case userId = "user_id"
        }
    }

    struct PostsInsert: Codable, Hashable, Sendable {
        let caption: String?
        let createdAt: String?
        let id: UUID?
        let imagePath: String
        let location: GeographySelect
        let locationName: String?
        let scope: String?
        let userId: UUID
        enum CodingKeys: String, CodingKey {
            case caption
            case createdAt = "created_at"
            case id
            case imagePath = "image_path"
            case location
            case locationName = "location_name"
            case scope
            case userId = "user_id"
        }
    }

    struct PostsUpdate: Codable, Hashable, Sendable {
        let caption: String?
        let createdAt: String?
        let id: UUID?
        let imagePath: String?
        let location: GeographySelect?
        let locationName: String?
        let scope: String?
        let userId: UUID?
        enum CodingKeys: String, CodingKey {
            case caption
            case createdAt = "created_at"
            case id
            case imagePath = "image_path"
            case location
            case locationName = "location_name"
            case scope
            case userId = "user_id"
        }
    }

    // MARK: - Profiles

    struct ProfilesSelect: Codable, Hashable, Sendable {
        let bio: String?
        let createdAt: String?
        let displayName: String
        let friendCount: Int32?
        let gradientColors: [String]?
        let id: UUID
        let postCount: Int32?
        let username: String
        enum CodingKeys: String, CodingKey {
            case bio
            case createdAt = "created_at"
            case displayName = "display_name"
            case friendCount = "friend_count"
            case gradientColors = "gradient_colors"
            case id
            case postCount = "post_count"
            case username
        }
    }

    struct ProfilesInsert: Codable, Hashable, Sendable {
        let bio: String?
        let createdAt: String?
        let displayName: String
        let friendCount: Int32?
        let gradientColors: [String]?
        let id: UUID
        let postCount: Int32?
        let username: String
        enum CodingKeys: String, CodingKey {
            case bio
            case createdAt = "created_at"
            case displayName = "display_name"
            case friendCount = "friend_count"
            case gradientColors = "gradient_colors"
            case id
            case postCount = "post_count"
            case username
        }
    }

    struct ProfilesUpdate: Codable, Hashable, Sendable {
        let bio: String?
        let createdAt: String?
        let displayName: String?
        let friendCount: Int32?
        let gradientColors: [String]?
        let id: UUID?
        let postCount: Int32?
        let username: String?
        enum CodingKeys: String, CodingKey {
            case bio
            case createdAt = "created_at"
            case displayName = "display_name"
            case friendCount = "friend_count"
            case gradientColors = "gradient_colors"
            case id
            case postCount = "post_count"
            case username
        }
    }
}
