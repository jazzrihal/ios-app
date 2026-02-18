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

    // MARK: - Auth

    /// The authenticated user's UUID, used for like/pin persistence.
    var userId: UUID?

    // MARK: - Paging State

    var currentIndex: Int

    // MARK: - Interaction State

    var likedPostIDs: Set<UUID> = []
    var pinnedPostIDs: Set<UUID> = []
    var showShareSheet: Bool = false

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
        likedPostIDs.contains(post.id)
    }

    var isPinned: Bool {
        pinnedPostIDs.contains(post.id)
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

    // MARK: - Load Existing Likes / Pins

    /// Fetches the user's existing likes and pins for the current set of post IDs.
    func loadLikesAndPins() {
        guard let userId else { return }
        let postIds = posts.map(\.id)

        Task { @MainActor in
            do {
                let likes: [PublicSchema.LikesSelect] = try await SupabaseManager.client
                    .from("likes")
                    .select()
                    .eq("user_id", value: userId)
                    .in("post_id", values: postIds)
                    .execute()
                    .value

                likedPostIDs = Set(likes.map(\.postId))
            } catch {
                print("[PostDetail] Failed to load likes: \(error)")
            }

            do {
                let pins: [PublicSchema.PinsSelect] = try await SupabaseManager.client
                    .from("pins")
                    .select()
                    .eq("user_id", value: userId)
                    .in("post_id", values: postIds)
                    .execute()
                    .value

                pinnedPostIDs = Set(pins.map(\.postId))
            } catch {
                print("[PostDetail] Failed to load pins: \(error)")
            }
        }
    }

    // MARK: - Action Handlers

    @MainActor
    func performAction(_ action: PostAction, store: MomentsStore) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        switch action {
        case .like:
            toggleLike()
        case .share:
            showShareSheet = true
        case .jump:
            store.pendingMoment = Moment(
                date: post.timestamp,
                locationName: post.locationName,
                coordinate: post.coordinate,
                addedAt: Date()
            )
            store.selectedTab = 0
            shouldDismiss = true
        case .pinToProfile:
            togglePin()
        }
    }

    // MARK: - Like / Pin Persistence

    private func toggleLike() {
        guard let userId else { return }
        let postId = post.id

        if isLiked {
            // Optimistic unlike
            likedPostIDs.remove(postId)
            Task {
                do {
                    try await SupabaseManager.client.from("likes")
                        .delete()
                        .eq("user_id", value: userId)
                        .eq("post_id", value: postId)
                        .execute()
                } catch {
                    likedPostIDs.insert(postId)
                    print("[PostDetail] Unlike failed: \(error)")
                }
            }
        } else {
            // Optimistic like
            likedPostIDs.insert(postId)
            triggerOverlayAnimation(icon: "heart.fill", color: .red)
            Task {
                do {
                    let insert = PublicSchema.LikesInsert(
                        createdAt: nil, postId: postId, userId: userId
                    )
                    try await SupabaseManager.client.from("likes")
                        .insert(insert)
                        .execute()
                } catch {
                    likedPostIDs.remove(postId)
                    print("[PostDetail] Like failed: \(error)")
                }
            }
        }
    }

    private func togglePin() {
        guard let userId else { return }
        let postId = post.id

        if isPinned {
            // Optimistic unpin
            pinnedPostIDs.remove(postId)
            Task {
                do {
                    try await SupabaseManager.client.from("pins")
                        .delete()
                        .eq("user_id", value: userId)
                        .eq("post_id", value: postId)
                        .execute()
                } catch {
                    pinnedPostIDs.insert(postId)
                    print("[PostDetail] Unpin failed: \(error)")
                }
            }
        } else {
            // Optimistic pin
            pinnedPostIDs.insert(postId)
            triggerOverlayAnimation(icon: "pin.fill", color: .orange)
            Task {
                do {
                    let insert = PublicSchema.PinsInsert(
                        createdAt: nil, postId: postId, userId: userId
                    )
                    try await SupabaseManager.client.from("pins")
                        .insert(insert)
                        .execute()
                } catch {
                    pinnedPostIDs.remove(postId)
                    print("[PostDetail] Pin failed: \(error)")
                }
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
