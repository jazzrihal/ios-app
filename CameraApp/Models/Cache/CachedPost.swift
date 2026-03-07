import Foundation
import SwiftData

@Model
final class CachedPost {
    var postId: UUID
    var cacheKey: String
    var cachedAt: Date
    var sortOrder: Int

    var userId: UUID
    var username: String
    var displayName: String
    var gradientColorHexes: [String]
    var imagePath: String
    var caption: String
    var latitude: Double
    var longitude: Double
    var locationName: String
    var scope: String
    var postCreatedAt: String
    var distanceMeters: Double
    var isOwnPost: Bool
    var isPinnedByUser: Bool
    var isLikedByViewer: Bool
    var isPinnedByViewer: Bool
    var pinnedByUsername: String?
    var totalCount: Int

    init(
        postId: UUID,
        cacheKey: String,
        cachedAt: Date = Date(),
        sortOrder: Int,
        userId: UUID,
        username: String,
        displayName: String,
        gradientColorHexes: [String],
        imagePath: String,
        caption: String,
        latitude: Double,
        longitude: Double,
        locationName: String,
        scope: String,
        postCreatedAt: String,
        distanceMeters: Double,
        isOwnPost: Bool = false,
        isPinnedByUser: Bool = false,
        isLikedByViewer: Bool = false,
        isPinnedByViewer: Bool = false,
        pinnedByUsername: String? = nil,
        totalCount: Int = 0
    ) {
        self.postId = postId
        self.cacheKey = cacheKey
        self.cachedAt = cachedAt
        self.sortOrder = sortOrder
        self.userId = userId
        self.username = username
        self.displayName = displayName
        self.gradientColorHexes = gradientColorHexes
        self.imagePath = imagePath
        self.caption = caption
        self.latitude = latitude
        self.longitude = longitude
        self.locationName = locationName
        self.scope = scope
        self.postCreatedAt = postCreatedAt
        self.distanceMeters = distanceMeters
        self.isOwnPost = isOwnPost
        self.isPinnedByUser = isPinnedByUser
        self.isLikedByViewer = isLikedByViewer
        self.isPinnedByViewer = isPinnedByViewer
        self.pinnedByUsername = pinnedByUsername
        self.totalCount = totalCount
    }
}

// MARK: - Conversion Helpers

extension CachedPost {
    convenience init(from row: NearbyPostRow, cacheKey: String, sortOrder: Int) {
        self.init(
            postId: row.id,
            cacheKey: cacheKey,
            sortOrder: sortOrder,
            userId: row.userId,
            username: row.username,
            displayName: row.displayName,
            gradientColorHexes: row.gradientColors ?? [],
            imagePath: row.imagePath,
            caption: row.caption ?? "",
            latitude: row.latitude,
            longitude: row.longitude,
            locationName: row.locationName ?? "",
            scope: row.scope,
            postCreatedAt: row.createdAt,
            distanceMeters: row.distanceMeters,
            isLikedByViewer: row.isLikedByViewer,
            isPinnedByViewer: row.isPinnedByViewer,
            totalCount: row.totalCount ?? 0
        )
    }

    convenience init(from row: UserPostWithPinRow, cacheKey: String, sortOrder: Int) {
        self.init(
            postId: row.id,
            cacheKey: cacheKey,
            sortOrder: sortOrder,
            userId: row.userId,
            username: row.username,
            displayName: row.displayName,
            gradientColorHexes: row.gradientColors ?? [],
            imagePath: row.imagePath,
            caption: row.caption ?? "",
            latitude: row.latitude,
            longitude: row.longitude,
            locationName: row.locationName ?? "",
            scope: row.scope,
            postCreatedAt: row.createdAt,
            distanceMeters: 0,
            isOwnPost: row.isOwnPost,
            isPinnedByUser: row.isPinnedByUser,
            isLikedByViewer: row.isLikedByViewer,
            isPinnedByViewer: row.isPinnedByViewer,
            pinnedByUsername: row.isPinnedByUser ? row.username : nil,
            totalCount: row.totalCount
        )
    }

    convenience init(from row: PostRowWithoutLocation, cacheKey: String, sortOrder: Int) {
        self.init(
            postId: row.id,
            cacheKey: cacheKey,
            sortOrder: sortOrder,
            userId: row.userId,
            username: "",
            displayName: "",
            gradientColorHexes: [],
            imagePath: row.imagePath,
            caption: row.caption ?? "",
            latitude: row.latitude,
            longitude: row.longitude,
            locationName: row.locationName ?? "",
            scope: row.scope,
            postCreatedAt: row.createdAt ?? "",
            distanceMeters: 0
        )
    }

    func toImagePost() -> ImagePost {
        ImagePost(
            id: postId,
            imageURL: SupabaseManager.imageURL(for: imagePath),
            imagePath: imagePath,
            user: User(
                id: userId,
                username: username,
                displayName: displayName,
                bio: "",
                gradientColors: User.parseGradientColors(
                    gradientColorHexes.isEmpty ? nil : gradientColorHexes
                ),
                joinDate: Date(),
                postCount: 0,
                friendCount: 0,
                mutualFriendCount: 0
            ),
            caption: caption,
            coordinate: .init(latitude: latitude, longitude: longitude),
            locationName: locationName,
            timestamp: ISO8601DateFormatter.flexibleParse(postCreatedAt) ?? Date(),
            distanceMeters: distanceMeters,
            scope: PostScope(serverValue: scope),
            isPinnedByUser: isPinnedByUser,
            isOwnPost: isOwnPost,
            isLikedByViewer: isLikedByViewer,
            isPinnedByViewer: isPinnedByViewer,
            pinnedByUsername: pinnedByUsername,
            hasViewerState: true
        )
    }
}
