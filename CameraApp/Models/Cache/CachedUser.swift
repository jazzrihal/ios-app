import Foundation
import SwiftData

@Model
final class CachedUser {
    var userId: UUID
    var cacheKey: String
    var cachedAt: Date
    var sortOrder: Int

    var username: String
    var displayName: String
    var bio: String
    var gradientColorHexes: [String]
    var userCreatedAt: String
    var postCount: Int
    var friendCount: Int

    init(
        userId: UUID,
        cacheKey: String,
        cachedAt: Date = Date(),
        sortOrder: Int = 0,
        username: String,
        displayName: String,
        bio: String,
        gradientColorHexes: [String],
        userCreatedAt: String,
        postCount: Int,
        friendCount: Int
    ) {
        self.userId = userId
        self.cacheKey = cacheKey
        self.cachedAt = cachedAt
        self.sortOrder = sortOrder
        self.username = username
        self.displayName = displayName
        self.bio = bio
        self.gradientColorHexes = gradientColorHexes
        self.userCreatedAt = userCreatedAt
        self.postCount = postCount
        self.friendCount = friendCount
    }
}

// MARK: - Conversion Helpers

extension CachedUser {
    convenience init(from profile: PublicSchema.ProfilesSelect, cacheKey: String, sortOrder: Int = 0) {
        self.init(
            userId: profile.id,
            cacheKey: cacheKey,
            sortOrder: sortOrder,
            username: profile.username,
            displayName: profile.displayName,
            bio: profile.bio ?? "",
            gradientColorHexes: profile.gradientColors ?? [],
            userCreatedAt: profile.createdAt ?? "",
            postCount: Int(profile.postCount ?? 0),
            friendCount: Int(profile.friendCount ?? 0)
        )
    }

    convenience init(from user: User, cacheKey: String, sortOrder: Int = 0) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.init(
            userId: user.id,
            cacheKey: cacheKey,
            sortOrder: sortOrder,
            username: user.username,
            displayName: user.displayName,
            bio: user.bio,
            gradientColorHexes: [],
            userCreatedAt: formatter.string(from: user.joinDate),
            postCount: user.postCount,
            friendCount: user.friendCount
        )
    }

    func toUser() -> User {
        User(
            id: userId,
            username: username,
            displayName: displayName,
            bio: bio,
            gradientColors: User.parseGradientColors(
                gradientColorHexes.isEmpty ? nil : gradientColorHexes
            ),
            joinDate: ISO8601DateFormatter.flexibleParse(userCreatedAt) ?? Date(),
            postCount: postCount,
            friendCount: friendCount,
            mutualFriendCount: 0
        )
    }
}
