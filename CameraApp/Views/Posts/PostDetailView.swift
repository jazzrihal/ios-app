import SwiftUI
import UIKit

// MARK: - Preference Key for Icon Frames

private struct ActionFramePreferenceKey: PreferenceKey {
    static var defaultValue: [PostAction: CGRect] = [:]
    static func reduce(value: inout [PostAction: CGRect], nextValue: () -> [PostAction: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

// MARK: - Post Detail View

struct PostDetailView: View {
    let posts: [ImagePost]
    let initialIndex: Int
    let queryDate: Date

    @Environment(MomentsStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    // Paging state
    @State private var currentIndex: Int = 0

    // Zoom state
    @State private var currentZoom: CGFloat = 0
    @State private var totalZoom: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var imageSize: CGSize = .zero

    // Long-press overlay state
    @GestureState private var isInteracting: Bool = false
    @State private var isPressing: Bool = false
    @State private var dragLocation: CGPoint? = nil
    @State private var hoveredAction: PostAction? = nil
    @State private var likedPostIDs: Set<UUID> = []
    @State private var pinnedPostIDs: Set<UUID> = []
    @State private var showShareSheet: Bool = false
    @State private var actionFrames: [PostAction: CGRect] = [:]

    // Overlay icon animation state (shared by like & pin feedback)
    @State private var overlayIcon: String? = nil
    @State private var overlayColor: Color = .clear
    @State private var overlayScale: CGFloat = 0
    @State private var overlayOpacity: Double = 0

    private var post: ImagePost { posts[currentIndex] }
    private var isLiked: Bool { likedPostIDs.contains(post.id) }
    private var isPinned: Bool { pinnedPostIDs.contains(post.id) }

    private var effectiveZoom: CGFloat {
        max(1, min(totalZoom + currentZoom, 5))
    }

    /// Maximum offset allowed so the image edge never goes past the container edge.
    private func maxOffset(for zoom: CGFloat) -> CGSize {
        let maxW = max(0, imageSize.width * (zoom - 1) / 2)
        let maxH = max(0, imageSize.height * (zoom - 1) / 2)
        return CGSize(width: maxW, height: maxH)
    }

    private func clampedOffset(_ proposed: CGSize, zoom: CGFloat) -> CGSize {
        let limit = maxOffset(for: zoom)
        return CGSize(
            width: min(limit.width, max(-limit.width, proposed.width)),
            height: min(limit.height, max(-limit.height, proposed.height))
        )
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Paged image layer
            TabView(selection: $currentIndex) {
                ForEach(Array(posts.enumerated()), id: \.element.id) { index, _ in
                    postImage(for: posts[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Action feedback animation overlay (like / pin)
            if let icon = overlayIcon {
                Image(systemName: icon)
                    .font(.system(size: 100))
                    .foregroundStyle(overlayColor)
                    .scaleEffect(overlayScale)
                    .opacity(overlayOpacity)
                    .shadow(color: overlayColor.opacity(0.4), radius: 12, x: 0, y: 4)
                    .allowsHitTesting(false)
            }

            // Caption + action overlay when pressing
            if isPressing {
                pressOverlay
            }

            // Close button, like indicator & metadata
            if !isPressing {
                VStack {
                    HStack {
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(10)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .padding(.leading, 16)
                        .padding(.top, 12)

                        Spacer()

                        HStack(spacing: 8) {
                            if isPinned {
                                Image(systemName: "pin.fill")
                                    .font(.body)
                                    .foregroundStyle(.orange)
                                    .padding(10)
                                    .background(.ultraThinMaterial, in: Circle())
                            }

                            if isLiked {
                                Image(systemName: "heart.fill")
                                    .font(.body)
                                    .foregroundStyle(.red)
                                    .padding(10)
                                    .background(.ultraThinMaterial, in: Circle())
                            }
                        }
                        .padding(.trailing, 16)
                        .padding(.top, 8)
                    }

                    Spacer()

                    // Post metadata
                    postMetadata
                }
            }
        }
        .coordinateSpace(name: "postDetail")
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .onAppear { currentIndex = initialIndex }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [post.imageURL])
        }
        .onChange(of: currentIndex) { _, _ in
            resetZoom()
        }
        .onChange(of: isInteracting) { _, interacting in
            if !interacting {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isPressing = false
                }
                dragLocation = nil
                hoveredAction = nil
            }
        }
        .onChange(of: dragLocation) { _, newLocation in
            updateHoveredAction(at: newLocation)
        }
    }

    // MARK: - Post Image

    private func postImage(for displayPost: ImagePost) -> some View {
        AsyncImage(url: displayPost.imageURL) { phase in
            switch phase {
            case .empty:
                ProgressView()
                    .tint(.white)
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
                    .overlay(
                        Color.white
                            .opacity(isPressing ? 1 : 0)
                            .animation(.easeInOut(duration: 0.2), value: isPressing)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        GeometryReader { geo in
                            Color.clear
                                .onAppear { imageSize = geo.size }
                                .onChange(of: geo.size) { _, newSize in
                                    imageSize = newSize
                                }
                        }
                    )
                    .scaleEffect(effectiveZoom)
                    .offset(offset)
                    .gesture(zoomGestures)
                    .simultaneousGesture(longPressGesture)
                    .onTapGesture(count: 2) {
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
                    .clipped()
            case .failure:
                VStack(spacing: 6) {
                    Image(systemName: "photo.badge.exclamationmark")
                        .font(.title2)
                    Text("Failed to load")
                        .font(.caption)
                }
                .foregroundStyle(.gray)
            @unknown default:
                EmptyView()
            }
        }
    }

    // MARK: - Press Overlay

    private var pressOverlay: some View {
        ZStack {
            // Caption centered on screen
            Text(post.caption)
                .font(.title3.bold())
                .foregroundStyle(.black)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .transition(.scale(scale: 0.9).combined(with: .opacity))

            // Action buttons at the bottom
            VStack {
                Spacer()

                HStack(spacing: 40) {
                    ForEach(PostAction.allCases, id: \.self) { action in
                        actionIcon(for: action)
                    }
                }
                .onPreferenceChange(ActionFramePreferenceKey.self) { frames in
                    actionFrames = frames
                }
                .padding(.bottom, 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Post Metadata

    private var postMetadata: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(post.user.displayName)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)

            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.caption2)
                Text(post.timestamp.formatted(.dateTime.month(.abbreviated).day().year().hour().minute()))
                    .font(.caption)
            }
            .foregroundStyle(.white.opacity(0.7))

            HStack(spacing: 4) {
                Image(systemName: "location")
                    .font(.caption2)
                Text(post.locationName)
                    .font(.caption)
            }
            .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.4)],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
        )
    }

    private func actionIcon(for action: PostAction) -> some View {
        let isHovered = hoveredAction == action

        let iconName: String
        let iconColor: Color
        switch action {
        case .like where isLiked:
            iconName = "heart.fill"
            iconColor = .red
        case .pinToProfile where isPinned:
            iconName = "pin.fill"
            iconColor = .orange
        default:
            iconName = action.iconName
            iconColor = Color(.darkGray)
        }

        return VStack(spacing: 8) {
            Image(systemName: iconName)
                .font(.title.weight(.semibold))
                .foregroundStyle(iconColor)
                .frame(width: 64, height: 64)
                .scaleEffect(isHovered ? 1.3 : 1.0)
                .shadow(color: isHovered ? .black.opacity(0.15) : .clear, radius: 8)
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isHovered)

            Text(action.label)
                .font(.caption.weight(.medium))
                .foregroundStyle(isHovered ? Color(.darkGray) : Color(.darkGray).opacity(0.7))
        }
        .background(
            GeometryReader { geo in
                Color.clear
                    .preference(
                        key: ActionFramePreferenceKey.self,
                        value: [action: geo.frame(in: .named("postDetail"))]
                    )
            }
        )
    }

    // MARK: - Zoom Gestures

    private var zoomGestures: some Gesture {
        let pinch = MagnifyGesture()
            .onChanged { value in
                guard !isPressing else { return }
                currentZoom = value.magnification - 1
            }
            .onEnded { value in
                guard !isPressing else { return }
                totalZoom = effectiveZoom
                currentZoom = 0
                if totalZoom <= 1.05 {
                    resetZoom()
                } else {
                    let clamped = clampedOffset(offset, zoom: totalZoom)
                    if clamped != offset {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            offset = clamped
                            lastOffset = clamped
                        }
                    }
                }
            }

        let drag = DragGesture()
            .onChanged { value in
                guard !isPressing, effectiveZoom > 1 else { return }
                let proposed = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
                offset = clampedOffset(proposed, zoom: effectiveZoom)
            }
            .onEnded { _ in
                guard !isPressing else { return }
                lastOffset = offset
            }

        return pinch.simultaneously(with: drag)
    }

    private func resetZoom() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            totalZoom = 1
            currentZoom = 0
            offset = .zero
            lastOffset = .zero
        }
    }

    // MARK: - Long Press Gesture

    private var longPressGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.01)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named("postDetail")))
            .updating($isInteracting) { _, state, _ in
                state = true
            }
            .onChanged { value in
                switch value {
                case .first(true):
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isPressing = true
                    }
                case .second(true, let drag):
                    if !isPressing {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isPressing = true
                        }
                    }
                    dragLocation = drag?.location
                default:
                    break
                }
            }
            .onEnded { _ in
                if let action = hoveredAction {
                    performAction(action)
                }
            }
    }

    // MARK: - Hover Detection

    private func updateHoveredAction(at point: CGPoint?) {
        guard let point = point else {
            hoveredAction = nil
            return
        }

        var closest: PostAction? = nil
        var closestDistance: CGFloat = .infinity
        let threshold: CGFloat = 80

        for (action, frame) in actionFrames {
            let center = CGPoint(x: frame.midX, y: frame.midY)
            let dx = point.x - center.x
            let dy = point.y - center.y
            let distance = sqrt(dx * dx + dy * dy)

            if distance < threshold && distance < closestDistance {
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

    private func performAction(_ action: PostAction) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        switch action {
        case .like:
            if isLiked {
                likedPostIDs.remove(post.id)
            } else {
                likedPostIDs.insert(post.id)
                triggerOverlayAnimation(icon: "heart.fill", color: .red)
            }
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
            dismiss()
        case .pinToProfile:
            if isPinned {
                pinnedPostIDs.remove(post.id)
            } else {
                pinnedPostIDs.insert(post.id)
                triggerOverlayAnimation(icon: "pin.fill", color: .orange)
            }
        }
    }

    // MARK: - Overlay Animation

    private func triggerOverlayAnimation(icon: String, color: Color) {
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeInOut(duration: 0.15)) {
                overlayScale = 1.0
            }
        }

        // Phase 3: Fade out and hide
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeOut(duration: 0.4)) {
                overlayOpacity = 0
                overlayScale = 0.8
            }
        }

        // Clean up
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            overlayIcon = nil
        }
    }
}

// MARK: - Preview

import CoreLocation

#Preview {
    NavigationStack {
        PostDetailView(
            posts: ImagePost.samplePosts(
                near: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                around: Date()
            ),
            initialIndex: 0,
            queryDate: Date()
        )
    }
    .environment(FriendsStore())
    .environment(MomentsStore())
}
