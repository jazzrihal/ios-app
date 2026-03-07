@testable import CameraApp
import CoreLocation
import Foundation
import SwiftUI
import Testing

@Suite("FriendsFeedViewModel")
struct FriendsFeedViewModelTests {
    @Test("refresh toggles isRefreshing for in-flight work")
    @MainActor
    func refreshTogglesIsRefreshing() async {
        let viewModel = FriendsFeedViewModel()
        let repository = MockPostRepository()
        repository.pauseFirstPage = true
        repository.firstPageResult = makePosts(count: 20)
        viewModel.postRepository = repository

        let friends = [makeUser()]
        let refreshTask = Task { await viewModel.refreshPosts(friends: friends) }

        await Task.yield()
        #expect(viewModel.isRefreshing)

        repository.resumeFirstPage()
        await refreshTask.value

        #expect(!viewModel.isRefreshing)
        #expect(repository.invalidateFriendFeedCallCount == 1)
    }

    @Test("loadNextPage is blocked while refresh is active")
    @MainActor
    func loadNextPageBlockedDuringRefresh() async {
        let viewModel = FriendsFeedViewModel()
        let repository = MockPostRepository()
        repository.pauseFirstPage = true
        repository.firstPageResult = makePosts(count: 20)
        repository.nextPageResult = makePosts(count: 5)
        viewModel.postRepository = repository

        let friends = [makeUser()]
        let refreshTask = Task { await viewModel.refreshPosts(friends: friends) }

        await Task.yield()
        #expect(viewModel.isRefreshing)

        await viewModel.loadNextPage(friends: friends)
        #expect(repository.friendFeedCallOffsets == [0])

        repository.resumeFirstPage()
        await refreshTask.value
    }

    @Test("TabRefreshable refresh uses latest friend context")
    @MainActor
    func tabRefreshableRefreshUsesLatestContext() async {
        let viewModel = FriendsFeedViewModel()
        let repository = MockPostRepository()
        repository.firstPageResult = makePosts(count: 20)
        viewModel.postRepository = repository

        viewModel.setRefreshContext(friends: [makeUser()])
        await viewModel.refresh()

        #expect(repository.invalidateFriendFeedCallCount == 1)
        #expect(repository.friendFeedCallOffsets == [0])
    }

    @MainActor
    private func makeUser() -> User {
        User(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000777")!,
            username: "friend",
            displayName: "Friend User",
            bio: "",
            gradientColors: [.gray, Color(.systemGray3)],
            joinDate: Date(),
            postCount: 0,
            friendCount: 0,
            mutualFriendCount: 0
        )
    }

    @MainActor
    private func makePosts(count: Int) -> [ImagePost] {
        let user = makeUser()
        return (0 ..< count).map { index in
            ImagePost(
                id: UUID(),
                imageURL: URL(string: "https://example.com/\(index).jpg")!,
                imagePath: "friend/\(index).jpg",
                user: user,
                caption: "Caption \(index)",
                coordinate: CLLocationCoordinate2D(latitude: 37.0, longitude: -122.0),
                locationName: "San Francisco",
                timestamp: Date(),
                distanceMeters: 0,
                scope: .public
            )
        }
    }
}

@MainActor
private final class MockPostRepository: PostRepository {
    var firstPageResult: [ImagePost] = []
    var nextPageResult: [ImagePost] = []
    var pauseFirstPage = false
    var invalidateFriendFeedCallCount = 0
    var friendFeedCallOffsets: [Int] = []

    private var firstPageContinuation: CheckedContinuation<Void, Never>?

    func nearbyPosts(params _: NearbyPostsParams) async throws -> [ImagePost] {
        []
    }

    func nearbyPostsNextPage(params _: NearbyPostsParams) async throws -> [ImagePost] {
        []
    }

    func userPostsAndPins(userId _: UUID, pageSize _: Int, pageOffset _: Int) async throws -> [ImagePost] {
        []
    }

    func friendFeedPosts(friendIds _: [UUID], friends _: [User], pageSize _: Int, from: Int) async throws -> [ImagePost] {
        friendFeedCallOffsets.append(from)
        if pauseFirstPage, from == 0 {
            await withCheckedContinuation { continuation in
                firstPageContinuation = continuation
            }
        }
        return from == 0 ? firstPageResult : nextPageResult
    }

    func updatePost(id _: UUID, caption _: String?, scope _: PostScope) async throws {}

    func deletePost(id _: UUID, imagePath _: String) async throws {}

    func invalidateUserPosts(_: UUID) {}

    func invalidateNearbyPosts() {}

    func invalidateFriendFeed() {
        invalidateFriendFeedCallCount += 1
    }

    func resumeFirstPage() {
        pauseFirstPage = false
        firstPageContinuation?.resume()
        firstPageContinuation = nil
    }
}
