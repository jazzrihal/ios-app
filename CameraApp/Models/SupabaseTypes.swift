import Foundation
import Supabase

internal enum GraphqlPublicSchema {
}
internal enum PublicSchema {
  internal struct BadgeTypesSelect: Codable, Hashable, Sendable {
    internal let description: String
    internal let id: String
    internal let name: String
    internal enum CodingKeys: String, CodingKey {
      case description = "description"
      case id = "id"
      case name = "name"
    }
  }
  internal struct BadgeTypesInsert: Codable, Hashable, Sendable {
    internal let description: String
    internal let id: String
    internal let name: String
    internal enum CodingKeys: String, CodingKey {
      case description = "description"
      case id = "id"
      case name = "name"
    }
  }
  internal struct BadgeTypesUpdate: Codable, Hashable, Sendable {
    internal let description: String?
    internal let id: String?
    internal let name: String?
    internal enum CodingKeys: String, CodingKey {
      case description = "description"
      case id = "id"
      case name = "name"
    }
  }
  internal struct DeviceTokensSelect: Codable, Hashable, Sendable {
    internal let createdAt: String?
    internal let id: UUID
    internal let platform: String?
    internal let token: String
    internal let userId: UUID
    internal enum CodingKeys: String, CodingKey {
      case createdAt = "created_at"
      case id = "id"
      case platform = "platform"
      case token = "token"
      case userId = "user_id"
    }
  }
  internal struct DeviceTokensInsert: Codable, Hashable, Sendable {
    internal let createdAt: String?
    internal let id: UUID?
    internal let platform: String?
    internal let token: String
    internal let userId: UUID
    internal enum CodingKeys: String, CodingKey {
      case createdAt = "created_at"
      case id = "id"
      case platform = "platform"
      case token = "token"
      case userId = "user_id"
    }
  }
  internal struct DeviceTokensUpdate: Codable, Hashable, Sendable {
    internal let createdAt: String?
    internal let id: UUID?
    internal let platform: String?
    internal let token: String?
    internal let userId: UUID?
    internal enum CodingKeys: String, CodingKey {
      case createdAt = "created_at"
      case id = "id"
      case platform = "platform"
      case token = "token"
      case userId = "user_id"
    }
  }
  internal struct FriendshipsSelect: Codable, Hashable, Sendable {
    internal let addresseeId: UUID
    internal let createdAt: String?
    internal let requesterId: UUID
    internal let status: String
    internal enum CodingKeys: String, CodingKey {
      case addresseeId = "addressee_id"
      case createdAt = "created_at"
      case requesterId = "requester_id"
      case status = "status"
    }
  }
  internal struct FriendshipsInsert: Codable, Hashable, Sendable {
    internal let addresseeId: UUID
    internal let createdAt: String?
    internal let requesterId: UUID
    internal let status: String?
    internal enum CodingKeys: String, CodingKey {
      case addresseeId = "addressee_id"
      case createdAt = "created_at"
      case requesterId = "requester_id"
      case status = "status"
    }
  }
  internal struct FriendshipsUpdate: Codable, Hashable, Sendable {
    internal let addresseeId: UUID?
    internal let createdAt: String?
    internal let requesterId: UUID?
    internal let status: String?
    internal enum CodingKeys: String, CodingKey {
      case addresseeId = "addressee_id"
      case createdAt = "created_at"
      case requesterId = "requester_id"
      case status = "status"
    }
  }
  internal struct LikesSelect: Codable, Hashable, Sendable {
    internal let createdAt: String?
    internal let postId: UUID
    internal let userId: UUID
    internal enum CodingKeys: String, CodingKey {
      case createdAt = "created_at"
      case postId = "post_id"
      case userId = "user_id"
    }
  }
  internal struct LikesInsert: Codable, Hashable, Sendable {
    internal let createdAt: String?
    internal let postId: UUID
    internal let userId: UUID
    internal enum CodingKeys: String, CodingKey {
      case createdAt = "created_at"
      case postId = "post_id"
      case userId = "user_id"
    }
  }
  internal struct LikesUpdate: Codable, Hashable, Sendable {
    internal let createdAt: String?
    internal let postId: UUID?
    internal let userId: UUID?
    internal enum CodingKeys: String, CodingKey {
      case createdAt = "created_at"
      case postId = "post_id"
      case userId = "user_id"
    }
  }
  internal struct MomentsSelect: Codable, Hashable, Sendable {
    internal let createdAt: String?
    internal let id: UUID
    internal let latitude: Double
    internal let location: GeographySelect?
    internal let locationName: String?
    internal let longitude: Double
    internal let momentDate: String
    internal let userId: UUID
    internal enum CodingKeys: String, CodingKey {
      case createdAt = "created_at"
      case id = "id"
      case latitude = "latitude"
      case location = "location"
      case locationName = "location_name"
      case longitude = "longitude"
      case momentDate = "moment_date"
      case userId = "user_id"
    }
  }
  internal struct MomentsInsert: Codable, Hashable, Sendable {
    internal let createdAt: String?
    internal let id: UUID?
    internal let latitude: Double
    internal let location: GeographySelect?
    internal let locationName: String?
    internal let longitude: Double
    internal let momentDate: String
    internal let userId: UUID
    internal enum CodingKeys: String, CodingKey {
      case createdAt = "created_at"
      case id = "id"
      case latitude = "latitude"
      case location = "location"
      case locationName = "location_name"
      case longitude = "longitude"
      case momentDate = "moment_date"
      case userId = "user_id"
    }
  }
  internal struct MomentsUpdate: Codable, Hashable, Sendable {
    internal let createdAt: String?
    internal let id: UUID?
    internal let latitude: Double?
    internal let location: GeographySelect?
    internal let locationName: String?
    internal let longitude: Double?
    internal let momentDate: String?
    internal let userId: UUID?
    internal enum CodingKeys: String, CodingKey {
      case createdAt = "created_at"
      case id = "id"
      case latitude = "latitude"
      case location = "location"
      case locationName = "location_name"
      case longitude = "longitude"
      case momentDate = "moment_date"
      case userId = "user_id"
    }
  }
  internal struct NotificationsSelect: Codable, Hashable, Sendable {
    internal let actorId: UUID
    internal let createdAt: String
    internal let entityId: UUID
    internal let entityType: String
    internal let id: UUID
    internal let metadata: AnyJSON
    internal let readAt: String?
    internal let recipientId: UUID
    internal let type: String
    internal enum CodingKeys: String, CodingKey {
      case actorId = "actor_id"
      case createdAt = "created_at"
      case entityId = "entity_id"
      case entityType = "entity_type"
      case id = "id"
      case metadata = "metadata"
      case readAt = "read_at"
      case recipientId = "recipient_id"
      case type = "type"
    }
  }
  internal struct NotificationsInsert: Codable, Hashable, Sendable {
    internal let actorId: UUID
    internal let createdAt: String?
    internal let entityId: UUID
    internal let entityType: String
    internal let id: UUID?
    internal let metadata: AnyJSON?
    internal let readAt: String?
    internal let recipientId: UUID
    internal let type: String
    internal enum CodingKeys: String, CodingKey {
      case actorId = "actor_id"
      case createdAt = "created_at"
      case entityId = "entity_id"
      case entityType = "entity_type"
      case id = "id"
      case metadata = "metadata"
      case readAt = "read_at"
      case recipientId = "recipient_id"
      case type = "type"
    }
  }
  internal struct NotificationsUpdate: Codable, Hashable, Sendable {
    internal let actorId: UUID?
    internal let createdAt: String?
    internal let entityId: UUID?
    internal let entityType: String?
    internal let id: UUID?
    internal let metadata: AnyJSON?
    internal let readAt: String?
    internal let recipientId: UUID?
    internal let type: String?
    internal enum CodingKeys: String, CodingKey {
      case actorId = "actor_id"
      case createdAt = "created_at"
      case entityId = "entity_id"
      case entityType = "entity_type"
      case id = "id"
      case metadata = "metadata"
      case readAt = "read_at"
      case recipientId = "recipient_id"
      case type = "type"
    }
  }
  internal struct PinsSelect: Codable, Hashable, Sendable {
    internal let createdAt: String?
    internal let postId: UUID
    internal let userId: UUID
    internal enum CodingKeys: String, CodingKey {
      case createdAt = "created_at"
      case postId = "post_id"
      case userId = "user_id"
    }
  }
  internal struct PinsInsert: Codable, Hashable, Sendable {
    internal let createdAt: String?
    internal let postId: UUID
    internal let userId: UUID
    internal enum CodingKeys: String, CodingKey {
      case createdAt = "created_at"
      case postId = "post_id"
      case userId = "user_id"
    }
  }
  internal struct PinsUpdate: Codable, Hashable, Sendable {
    internal let createdAt: String?
    internal let postId: UUID?
    internal let userId: UUID?
    internal enum CodingKeys: String, CodingKey {
      case createdAt = "created_at"
      case postId = "post_id"
      case userId = "user_id"
    }
  }
  internal struct PostsSelect: Codable, Hashable, Sendable {
    internal let caption: String?
    internal let createdAt: String?
    internal let id: UUID
    internal let imagePath: String
    internal let latitude: Double
    internal let location: GeographySelect?
    internal let locationName: String?
    internal let longitude: Double
    internal let scope: String
    internal let userId: UUID
    internal enum CodingKeys: String, CodingKey {
      case caption = "caption"
      case createdAt = "created_at"
      case id = "id"
      case imagePath = "image_path"
      case latitude = "latitude"
      case location = "location"
      case locationName = "location_name"
      case longitude = "longitude"
      case scope = "scope"
      case userId = "user_id"
    }
  }
  internal struct PostsInsert: Codable, Hashable, Sendable {
    internal let caption: String?
    internal let createdAt: String?
    internal let id: UUID?
    internal let imagePath: String
    internal let latitude: Double
    internal let location: GeographySelect?
    internal let locationName: String?
    internal let longitude: Double
    internal let scope: String?
    internal let userId: UUID
    internal enum CodingKeys: String, CodingKey {
      case caption = "caption"
      case createdAt = "created_at"
      case id = "id"
      case imagePath = "image_path"
      case latitude = "latitude"
      case location = "location"
      case locationName = "location_name"
      case longitude = "longitude"
      case scope = "scope"
      case userId = "user_id"
    }
  }
  internal struct PostsUpdate: Codable, Hashable, Sendable {
    internal let caption: String?
    internal let createdAt: String?
    internal let id: UUID?
    internal let imagePath: String?
    internal let latitude: Double?
    internal let location: GeographySelect?
    internal let locationName: String?
    internal let longitude: Double?
    internal let scope: String?
    internal let userId: UUID?
    internal enum CodingKeys: String, CodingKey {
      case caption = "caption"
      case createdAt = "created_at"
      case id = "id"
      case imagePath = "image_path"
      case latitude = "latitude"
      case location = "location"
      case locationName = "location_name"
      case longitude = "longitude"
      case scope = "scope"
      case userId = "user_id"
    }
  }
  internal struct ProfilesSelect: Codable, Hashable, Sendable {
    internal let bio: String?
    internal let createdAt: String?
    internal let displayName: String
    internal let friendCount: Int32?
    internal let gradientColors: [String]?
    internal let id: UUID
    internal let postCount: Int32?
    internal let username: String
    internal enum CodingKeys: String, CodingKey {
      case bio = "bio"
      case createdAt = "created_at"
      case displayName = "display_name"
      case friendCount = "friend_count"
      case gradientColors = "gradient_colors"
      case id = "id"
      case postCount = "post_count"
      case username = "username"
    }
  }
  internal struct ProfilesInsert: Codable, Hashable, Sendable {
    internal let bio: String?
    internal let createdAt: String?
    internal let displayName: String
    internal let friendCount: Int32?
    internal let gradientColors: [String]?
    internal let id: UUID
    internal let postCount: Int32?
    internal let username: String
    internal enum CodingKeys: String, CodingKey {
      case bio = "bio"
      case createdAt = "created_at"
      case displayName = "display_name"
      case friendCount = "friend_count"
      case gradientColors = "gradient_colors"
      case id = "id"
      case postCount = "post_count"
      case username = "username"
    }
  }
  internal struct ProfilesUpdate: Codable, Hashable, Sendable {
    internal let bio: String?
    internal let createdAt: String?
    internal let displayName: String?
    internal let friendCount: Int32?
    internal let gradientColors: [String]?
    internal let id: UUID?
    internal let postCount: Int32?
    internal let username: String?
    internal enum CodingKeys: String, CodingKey {
      case bio = "bio"
      case createdAt = "created_at"
      case displayName = "display_name"
      case friendCount = "friend_count"
      case gradientColors = "gradient_colors"
      case id = "id"
      case postCount = "post_count"
      case username = "username"
    }
  }
  internal struct UserBadgesSelect: Codable, Hashable, Sendable {
    internal let awardedAt: String
    internal let badgeType: String
    internal let id: UUID
    internal let metadata: AnyJSON
    internal let postId: UUID?
    internal let triggerKey: String
    internal let triggerType: String
    internal let userId: UUID
    internal enum CodingKeys: String, CodingKey {
      case awardedAt = "awarded_at"
      case badgeType = "badge_type"
      case id = "id"
      case metadata = "metadata"
      case postId = "post_id"
      case triggerKey = "trigger_key"
      case triggerType = "trigger_type"
      case userId = "user_id"
    }
  }
  internal struct UserBadgesInsert: Codable, Hashable, Sendable {
    internal let awardedAt: String?
    internal let badgeType: String
    internal let id: UUID?
    internal let metadata: AnyJSON?
    internal let postId: UUID?
    internal let triggerKey: String
    internal let triggerType: String
    internal let userId: UUID
    internal enum CodingKeys: String, CodingKey {
      case awardedAt = "awarded_at"
      case badgeType = "badge_type"
      case id = "id"
      case metadata = "metadata"
      case postId = "post_id"
      case triggerKey = "trigger_key"
      case triggerType = "trigger_type"
      case userId = "user_id"
    }
  }
  internal struct UserBadgesUpdate: Codable, Hashable, Sendable {
    internal let awardedAt: String?
    internal let badgeType: String?
    internal let id: UUID?
    internal let metadata: AnyJSON?
    internal let postId: UUID?
    internal let triggerKey: String?
    internal let triggerType: String?
    internal let userId: UUID?
    internal enum CodingKeys: String, CodingKey {
      case awardedAt = "awarded_at"
      case badgeType = "badge_type"
      case id = "id"
      case metadata = "metadata"
      case postId = "post_id"
      case triggerKey = "trigger_key"
      case triggerType = "trigger_type"
      case userId = "user_id"
    }
  }
}
