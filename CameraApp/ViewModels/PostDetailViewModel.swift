import CoreLocation
import Observation
import SwiftUI
import UIKit

// MARK: - Post Detail View Model

@Observable
final class PostDetailViewModel {
    // MARK: - Input

    let posts: [ImagePost]
    let queryDate: Date

    // MARK: - Shared Store

    var mutationStore: PostMutationStore?
    var badgeRepository: (any BadgeRepository)?

    // MARK: - Paging State

    var currentIndex: Int

    // MARK: - UI State

    var showShareSheet: Bool = false
    var badges: [PostBadge] = []

    // MARK: - Overlay Icon Animation State

    var overlayIcon: String?
    var overlayColor: Color = .clear
    var overlayScale: CGFloat = 0
    var overlayOpacity: Double = 0

    // MARK: - Navigation Side Effects

    /// Set to `true` when the view should dismiss (e.g. after "Jump" action).
    var shouldDismiss: Bool = false

    // MARK: - Computed Properties

    var post: ImagePost {
        posts[currentIndex]
    }

    var isLiked: Bool {
        mutationStore?.isLiked(post.id) ?? false
    }

    var isPinned: Bool {
        mutationStore?.isPinned(post.id) ?? false
    }

    // MARK: - Action State Helpers

    func isActionActive(_ action: PostAction) -> Bool {
        switch action {
        case .like: isLiked
        case .pinToProfile: isPinned
        default: false
        }
    }

    func iconName(for action: PostAction) -> String {
        isActionActive(action) ? action.activeIconName : action.iconName
    }

    func displayLabel(for action: PostAction) -> String {
        isActionActive(action) ? action.activeLabel : action.label
    }

    func accessibilityLabel(for action: PostAction) -> String {
        displayLabel(for: action)
    }

    func accessibilityHint(for action: PostAction) -> String {
        switch action {
        case .like:
            isLiked ? "Removes your like from this post" : "Adds a like to this post"
        case .share:
            "Opens the share sheet for this post"
        case .jump:
            "Navigates to this post's location on the map"
        case .pinToProfile:
            isPinned ? "Removes this post from your profile" : "Pins this post to your profile"
        }
    }

    // MARK: - Init

    init(posts: [ImagePost], initialIndex: Int, queryDate: Date) {
        self.posts = posts
        self.queryDate = queryDate
        currentIndex = initialIndex
    }

    // MARK: - Badge Loading

    @MainActor
    func loadBadges(postId: UUID) async {
        badges = []
        guard let badgeRepository else { return }
        do {
            badges = try await badgeRepository.fetchBadges(forPostId: postId)
        } catch {
            badges = []
        }
    }

    // MARK: - Action Handlers

    @MainActor
    func performAction(_ action: PostAction, momentsStore: MomentsStore) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        switch action {
        case .like:
            mutationStore?.toggleLike(post.id) { [weak self] icon, color in
                self?.triggerOverlayAnimation(icon: icon, color: color)
            }
        case .share:
            showShareSheet = true
        case .jump:
            momentsStore.pendingMoment = Moment(
                date: post.timestamp,
                locationName: post.locationName,
                coordinate: post.coordinate,
                addedAt: Date()
            )
            momentsStore.selectedTab = 0
            shouldDismiss = true
        case .pinToProfile:
            mutationStore?.togglePin(post.id) { [weak self] icon, color in
                self?.triggerOverlayAnimation(icon: icon, color: color)
            }
        }
    }

    // MARK: - Overlay Animation

    func triggerOverlayAnimation(icon: String, color: Color) {
        overlayIcon = icon
        overlayColor = color
        overlayScale = 0.4
        overlayOpacity = 1

        overlayScale = 1.0

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            overlayOpacity = 0
            overlayScale = 0.8

            try? await Task.sleep(for: .milliseconds(450))
            overlayIcon = nil
        }
    }
}
