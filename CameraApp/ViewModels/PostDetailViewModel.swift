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

    // MARK: - Zoom State

    var currentZoom: CGFloat = 0
    var totalZoom: CGFloat = 1
    var offset: CGSize = .zero
    var lastOffset: CGSize = .zero
    var imageSize: CGSize = .zero

    // MARK: - Long-Press Overlay State

    var isPressing: Bool = false
    var dragLocation: CGPoint?
    var hoveredAction: PostAction?
    var likedPostIDs: Set<UUID> = []
    var pinnedPostIDs: Set<UUID> = []
    var showShareSheet: Bool = false
    var actionFrames: [PostAction: CGRect] = [:]

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

    var effectiveZoom: CGFloat {
        max(1, min(totalZoom + currentZoom, 5))
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

    // MARK: - Zoom Helpers

    /// Maximum offset allowed so the image edge never goes past the container edge.
    func maxOffset(for zoom: CGFloat) -> CGSize {
        let maxW = max(0, imageSize.width * (zoom - 1) / 2)
        let maxH = max(0, imageSize.height * (zoom - 1) / 2)
        return CGSize(width: maxW, height: maxH)
    }

    func clampedOffset(_ proposed: CGSize, zoom: CGFloat) -> CGSize {
        let limit = maxOffset(for: zoom)
        return CGSize(
            width: min(limit.width, max(-limit.width, proposed.width)),
            height: min(limit.height, max(-limit.height, proposed.height))
        )
    }

    func resetZoom() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            totalZoom = 1
            currentZoom = 0
            offset = .zero
            lastOffset = .zero
        }
    }

    func handleDoubleTap() {
        guard !isPressing else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            if totalZoom > 1 {
                totalZoom = 1
                currentZoom = 0
                offset = .zero
                lastOffset = .zero
            } else {
                totalZoom = 3
                currentZoom = 0
            }
        }
    }

    func handlePageChange() {
        resetZoom()
    }

    // MARK: - Hover Detection

    func updateHoveredAction(at point: CGPoint?) {
        guard let point else {
            hoveredAction = nil
            return
        }

        var closest: PostAction?
        var closestDistance: CGFloat = .infinity
        let threshold: CGFloat = 80

        for (action, frame) in actionFrames {
            let center = CGPoint(x: frame.midX, y: frame.midY)
            let dx = point.x - center.x
            let dy = point.y - center.y
            let distance = sqrt(dx * dx + dy * dy)

            if distance < threshold, distance < closestDistance {
                closest = action
                closestDistance = distance
            }
        }

        if hoveredAction != closest {
            if closest != nil {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            }
            hoveredAction = closest
        }
    }

    // MARK: - Action Handlers

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
            triggerOverlayAnimation(icon: "heart.fill", color: .white)
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
            triggerOverlayAnimation(icon: "pin.fill", color: .white)
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
        overlayScale = 0
        overlayOpacity = 0

        // Phase 1: Scale up and fade in
        withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) {
            overlayScale = 1.2
            overlayOpacity = 1
        }

        // Phase 2: Settle to normal size
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            withAnimation(.easeInOut(duration: 0.15)) {
                overlayScale = 1.0
            }

            // Phase 3: Fade out and hide
            try? await Task.sleep(for: .milliseconds(500))
            withAnimation(.easeOut(duration: 0.4)) {
                overlayOpacity = 0
                overlayScale = 0.8
            }

            // Clean up
            try? await Task.sleep(for: .milliseconds(500))
            overlayIcon = nil
        }
    }

    // MARK: - Long Press Handling

    func handlePressBegan() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isPressing = true
        }
    }

    func handlePressEnded() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isPressing = false
        }
        dragLocation = nil
        hoveredAction = nil
    }
}
