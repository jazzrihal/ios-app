import CoreLocation
import Foundation
@testable import Pinstoria
import SwiftData
import SwiftUI
import Testing

@Suite("Frontend security hardening")
struct FrontendSecurityTests {
    @MainActor
    private func makeContext() -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer( // swiftlint:disable:this force_try
            for: CacheEntry.self, CachedPost.self, CachedUser.self, CachedMoment.self,
            configurations: config
        )
        return ModelContext(container)
    }

    @Test("post and moment cache keys are scoped to the signed-in viewer")
    func viewerScopedCacheKeys() throws {
        let viewerA = try #require(UUID(uuidString: "00000000-0000-0000-0000-0000000000AA"))
        let viewerB = try #require(UUID(uuidString: "00000000-0000-0000-0000-0000000000BB"))
        let targetUser = try #require(UUID(uuidString: "00000000-0000-0000-0000-0000000000CC"))
        let params = NearbyPostsParams(
            lng: -122.4194,
            lat: 37.7749,
            searchDate: "2026-05-31T08:00:00.000Z",
            radiusMeters: 5000
        )

        #expect(DefaultPostRepository.nearbyPostsCacheKey(params, viewerId: viewerA) !=
            DefaultPostRepository.nearbyPostsCacheKey(params, viewerId: viewerB))
        #expect(DefaultPostRepository.friendFeedCacheKey(viewerId: viewerA) !=
            DefaultPostRepository.friendFeedCacheKey(viewerId: viewerB))
        #expect(DefaultPostRepository.userPostsCacheKey(targetUser, viewerId: viewerA) !=
            DefaultPostRepository.userPostsCacheKey(targetUser, viewerId: viewerB))
        #expect(DefaultMomentRepository.momentsCacheKey(viewerId: viewerA) !=
            DefaultMomentRepository.momentsCacheKey(viewerId: viewerB))
    }

    @Test("session cache reset purges all SwiftData cache models")
    @MainActor
    func sessionCacheResetPurgesAllSwiftDataModels() {
        let context = makeContext()
        let invalidator = CacheInvalidator()
        invalidator.configure(
            posts: DefaultPostRepository(modelContext: context),
            friends: DefaultFriendRepository(modelContext: context),
            moments: DefaultMomentRepository(modelContext: context),
            profiles: DefaultProfileRepository(modelContext: context)
        )

        context.insert(CacheEntry(key: "viewer:abc:friend_feed"))
        context.insert(CacheEntry(key: "viewer:abc:moments"))
        context.insert(makeCachedPost(cacheKey: "viewer:abc:friend_feed"))
        context.insert(makeCachedUser(cacheKey: "friends:abc"))
        context.insert(CachedMoment(
            momentId: UUID(),
            cacheKey: "viewer:abc:moments",
            sortOrder: 0,
            momentDate: "2026-05-31T08:00:00.000Z",
            locationName: "San Francisco",
            latitude: 37.7749,
            longitude: -122.4194,
            momentCreatedAt: "2026-05-31T08:00:00.000Z",
            nearbyPostsData: nil
        ))
        try? context.save()

        invalidator.clearAllCachedData()

        #expect(((try? context.fetch(FetchDescriptor<CacheEntry>())) ?? []).isEmpty)
        #expect(((try? context.fetch(FetchDescriptor<CachedPost>())) ?? []).isEmpty)
        #expect(((try? context.fetch(FetchDescriptor<CachedUser>())) ?? []).isEmpty)
        #expect(((try? context.fetch(FetchDescriptor<CachedMoment>())) ?? []).isEmpty)
    }

    @Test("session-scoped stores clear user data on reset")
    @MainActor
    func sessionScopedStoresReset() {
        let friendsStore = FriendsStore()
        friendsStore.currentUserId = UUID()
        friendsStore.friends = [makeUser()]
        friendsStore.suggestedUsers = [makeUser()]
        friendsStore.incomingRequests = [makeUser()]
        friendsStore.pendingSentRequests = [UUID()]
        friendsStore.searchResults = [makeUser()]
        friendsStore.errorMessage = "sensitive backend detail"

        let momentsStore = MomentsStore()
        momentsStore.currentUserId = UUID()
        momentsStore.moments = [makeMoment()]
        momentsStore.nearbyPosts = [UUID(): []]
        momentsStore.pendingMoment = makeMoment()
        momentsStore.errorMessage = "sensitive backend detail"

        let mutationStore = PostMutationStore()
        mutationStore.currentUserId = UUID()
        mutationStore.likedPostIDs = [UUID()]
        mutationStore.pinnedPostIDs = [UUID()]

        friendsStore.resetSessionState()
        momentsStore.resetSessionState()
        mutationStore.reset()

        #expect(friendsStore.currentUserId == nil)
        #expect(friendsStore.friends.isEmpty)
        #expect(friendsStore.suggestedUsers.isEmpty)
        #expect(friendsStore.incomingRequests.isEmpty)
        #expect(friendsStore.pendingSentRequests.isEmpty)
        #expect(friendsStore.searchResults.isEmpty)
        #expect(friendsStore.errorMessage == nil)

        #expect(momentsStore.currentUserId == nil)
        #expect(momentsStore.moments.isEmpty)
        #expect(momentsStore.nearbyPosts.isEmpty)
        #expect(momentsStore.pendingMoment == nil)
        #expect(momentsStore.errorMessage == nil)

        #expect(mutationStore.currentUserId == nil)
        #expect(mutationStore.likedPostIDs.isEmpty)
        #expect(mutationStore.pinnedPostIDs.isEmpty)
    }

    @Test("upload processing requires the matching authenticated user")
    func uploadProcessingRequiresAuthenticatedOwner() throws {
        let owner = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000111"))
        let otherUser = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000222"))

        #expect(UploadManager.canProcessUpload(postUserId: owner, currentUserId: owner))
        #expect(!UploadManager.canProcessUpload(postUserId: owner, currentUserId: nil))
        #expect(!UploadManager.canProcessUpload(postUserId: owner, currentUserId: otherUser))
    }

    @Test("auth inputs are normalized and validated before Supabase calls")
    func authInputNormalizationAndValidation() {
        #expect(AuthManager.normalizedEmail("  PERSON@Example.COM  ") == "person@example.com")
        #expect(AuthManager.normalizedUsername("  User.Name_123  ") == "User.Name_123")
        #expect(AuthManager.signInValidationError(email: "invalid", password: "password123") != nil)
        #expect(AuthManager.signInValidationError(email: "user@example.com", password: "password123") == nil)
        #expect(AuthManager.signUpValidationError(
            email: "user@example.com",
            password: "short",
            username: "valid_user"
        ) != nil)
        #expect(AuthManager.signUpValidationError(
            email: "user@example.com",
            password: "password123",
            username: "bad username!"
        ) != nil)
        #expect(AuthManager.signUpValidationError(
            email: "user@example.com",
            password: "password123",
            username: "valid_user"
        ) == nil)
    }

    @Test("post owner mutations require the active viewer to own the post")
    func postOwnerMutationsRequireActiveOwner() throws {
        let owner = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000333"))
        let otherUser = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000444"))

        #expect(DefaultPostRepository.canMutatePost(ownerId: owner, viewerId: owner))
        #expect(!DefaultPostRepository.canMutatePost(ownerId: owner, viewerId: nil))
        #expect(!DefaultPostRepository.canMutatePost(ownerId: owner, viewerId: otherUser))
    }

    @Test("restricted posts do not expose raw public image URLs through sharing")
    func restrictedPostsCannotBeSharedByRawURL() {
        #expect(PostAction.availableActions(for: .public).contains(.share))
        #expect(!PostAction.availableActions(for: .friends).contains(.share))
        #expect(!PostAction.availableActions(for: .private).contains(.share))
    }

    private func makeCachedPost(cacheKey: String) -> CachedPost {
        CachedPost(
            postId: UUID(),
            cacheKey: cacheKey,
            sortOrder: 0,
            userId: UUID(),
            username: "user",
            displayName: "User",
            gradientColorHexes: [],
            imagePath: "user/post.jpg",
            caption: "caption",
            latitude: 37.7749,
            longitude: -122.4194,
            locationName: "San Francisco",
            scope: "friends",
            postCreatedAt: "2026-05-31T08:00:00.000Z",
            distanceMeters: 0
        )
    }

    private func makeCachedUser(cacheKey: String) -> CachedUser {
        CachedUser(
            userId: UUID(),
            cacheKey: cacheKey,
            sortOrder: 0,
            username: "user",
            displayName: "User",
            bio: "",
            gradientColorHexes: [],
            userCreatedAt: "2026-05-31T08:00:00.000Z",
            postCount: 0,
            friendCount: 0
        )
    }

    @MainActor
    private func makeUser() -> User {
        User(
            id: UUID(),
            username: "user",
            displayName: "User",
            bio: "",
            gradientColors: [],
            joinDate: Date(),
            postCount: 0,
            friendCount: 0,
            mutualFriendCount: 0
        )
    }

    private func makeMoment() -> Moment {
        Moment(
            id: UUID(),
            date: Date(),
            locationName: "San Francisco",
            coordinate: .init(latitude: 37.7749, longitude: -122.4194),
            addedAt: Date()
        )
    }
}
