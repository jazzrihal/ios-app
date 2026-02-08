import SwiftUI
import UIKit

// MARK: - Post Action

enum PostAction: CaseIterable, Hashable {
    case like, share, jump

    var iconName: String {
        switch self {
        case .like: return "heart"
        case .share: return "square.and.arrow.up"
        case .jump: return "scope"
        }
    }

    var label: String {
        switch self {
        case .like: return "Like"
        case .share: return "Share"
        case .jump: return "Jump"
        }
    }
}

// MARK: - Preference Key for Icon Frames

private struct ActionFramePreferenceKey: PreferenceKey {
    static var defaultValue: [PostAction: CGRect] = [:]
    static func reduce(value: inout [PostAction: CGRect], nextValue: () -> [PostAction: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

// MARK: - Post Detail View

struct PostDetailView: View {
    let post: ImagePost
    let queryDate: Date

    @Environment(MomentsStore.self) private var store
    @Environment(\.dismiss) private var dismiss

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
    @State private var isLiked: Bool = false
    @State private var showShareSheet: Bool = false
    @State private var actionFrames: [PostAction: CGRect] = [:]

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

            // Image layer
            postImage

            // Overlay when pressing
            if isPressing {
                pressOverlay
            }

            // Persistent like indicator
            if isLiked && !isPressing {
                likeIndicator
            }
        }
        .coordinateSpace(name: "postDetail")
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [post.imageURL])
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

    private var postImage: some View {
        AsyncImage(url: post.imageURL) { phase in
            switch phase {
            case .empty:
                ProgressView()
                    .tint(.white)
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
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
                    .blur(radius: isPressing ? 20 : 0)
                    .animation(.easeInOut(duration: 0.2), value: isPressing)
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
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Text(post.caption)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .shadow(color: .black.opacity(0.6), radius: 4, y: 2)

                HStack(spacing: 40) {
                    ForEach(PostAction.allCases, id: \.self) { action in
                        actionIcon(for: action)
                    }
                }
                .onPreferenceChange(ActionFramePreferenceKey.self) { frames in
                    actionFrames = frames
                }
            }
        }
        .transition(.opacity)
        .allowsHitTesting(false)
    }

    private func actionIcon(for action: PostAction) -> some View {
        let isHovered = hoveredAction == action
        let iconName: String = {
            if action == .like && isLiked {
                return "heart.fill"
            }
            return action.iconName
        }()

        return VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 64, height: 64)

                Image(systemName: iconName)
                    .font(.title2)
                    .foregroundStyle(action == .like && isLiked ? .red : .white)
            }
            .scaleEffect(isHovered ? 1.3 : 1.0)
            .shadow(color: isHovered ? .white.opacity(0.4) : .clear, radius: 8)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isHovered)

            Text(action.label)
                .font(.caption.weight(.medium))
                .foregroundStyle(isHovered ? .white : .white.opacity(0.7))
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

    // MARK: - Like Indicator

    private var likeIndicator: some View {
        VStack {
            HStack {
                Spacer()
                Image(systemName: "heart.fill")
                    .font(.body)
                    .foregroundStyle(.red)
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
                    .padding(.trailing, 16)
                    .padding(.top, 8)
            }
            Spacer()
        }
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
        LongPressGesture(minimumDuration: 0.3)
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
            isLiked.toggle()
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
        }
    }
}

// MARK: - Share Sheet

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

import CoreLocation

#Preview {
    NavigationStack {
        PostDetailView(
            post: ImagePost.samplePosts(
                near: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                around: Date()
            ).first!,
            queryDate: Date()
        )
    }
    .environment(FriendsStore())
    .environment(MomentsStore())
}
