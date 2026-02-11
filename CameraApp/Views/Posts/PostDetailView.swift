import CoreLocation
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
    @Environment(MomentsStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: PostDetailViewModel

    /// `@GestureState` must remain in the view (SwiftUI requirement).
    @GestureState private var isInteracting: Bool = false

    init(posts: [ImagePost], initialIndex: Int, queryDate: Date) {
        _viewModel = State(initialValue: PostDetailViewModel(
            posts: posts,
            initialIndex: initialIndex,
            queryDate: queryDate
        ))
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Paged image layer
            TabView(selection: $viewModel.currentIndex) {
                ForEach(Array(viewModel.posts.enumerated()), id: \.element.id) { index, _ in
                    postImage(for: viewModel.posts[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Action feedback animation overlay (like / pin)
            if let icon = viewModel.overlayIcon {
                Image(systemName: icon)
                    .font(.system(size: 100))
                    .foregroundStyle(viewModel.overlayColor)
                    .scaleEffect(viewModel.overlayScale)
                    .opacity(viewModel.overlayOpacity)
                    .shadow(color: viewModel.overlayColor.opacity(0.4), radius: 12, x: 0, y: 4)
                    .allowsHitTesting(false)
            }

            // Caption + action overlay when pressing
            if viewModel.isPressing {
                pressOverlay
            }

            // Close button, like indicator & metadata
            if !viewModel.isPressing {
                VStack {
                    topBar
                    Spacer()
                    postMetadata
                }
            }
        }
        .coordinateSpace(name: "postDetail")
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $viewModel.showShareSheet) {
            ShareSheet(items: [viewModel.post.imageURL])
        }
        .onChange(of: viewModel.currentIndex) { _, _ in
            viewModel.handlePageChange()
        }
        .onChange(of: isInteracting) { _, interacting in
            if !interacting {
                viewModel.handlePressEnded()
            }
        }
        .onChange(of: viewModel.dragLocation) { _, newLocation in
            viewModel.updateHoveredAction(at: newLocation)
        }
        .onChange(of: viewModel.shouldDismiss) { _, shouldDismiss in
            if shouldDismiss { dismiss() }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
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
                if viewModel.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.body)
                        .foregroundStyle(.orange)
                        .padding(10)
                        .background(.ultraThinMaterial, in: Circle())
                }

                if viewModel.isLiked {
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
    }

    // MARK: - Post Image

    private func postImage(for displayPost: ImagePost) -> some View {
        AsyncImage(url: displayPost.imageURL) { phase in
            switch phase {
            case .empty:
                ProgressView()
                    .tint(.white)
            case let .success(image):
                image
                    .resizable()
                    .scaledToFit()
                    .overlay(
                        Color.white
                            .opacity(viewModel.isPressing ? 1 : 0)
                            .animation(.easeInOut(duration: 0.2), value: viewModel.isPressing)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        GeometryReader { geo in
                            Color.clear
                                .onAppear { viewModel.imageSize = geo.size }
                                .onChange(of: geo.size) { _, newSize in
                                    viewModel.imageSize = newSize
                                }
                        }
                    )
                    .scaleEffect(viewModel.effectiveZoom)
                    .offset(viewModel.offset)
                    .gesture(zoomGestures)
                    .simultaneousGesture(longPressGesture)
                    .onTapGesture(count: 2) {
                        viewModel.handleDoubleTap()
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
            Text(viewModel.post.caption)
                .font(.title3.bold())
                .foregroundStyle(.black)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .transition(.scale(scale: 0.9).combined(with: .opacity))

            VStack {
                Spacer()

                HStack(spacing: 40) {
                    ForEach(PostAction.allCases, id: \.self) { action in
                        actionIcon(for: action)
                    }
                }
                .onPreferenceChange(ActionFramePreferenceKey.self) { frames in
                    viewModel.actionFrames = frames
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
            Text(viewModel.post.user.displayName)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)

            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.caption2)
                Text(viewModel.post.timestamp.formatted(.dateTime.month(.abbreviated).day().year().hour().minute()))
                    .font(.caption)
            }
            .foregroundStyle(.white.opacity(0.7))

            HStack(spacing: 4) {
                Image(systemName: "location")
                    .font(.caption2)
                Text(viewModel.post.locationName)
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

    // MARK: - Action Icon

    private func actionIcon(for action: PostAction) -> some View {
        let isHovered = viewModel.hoveredAction == action

        let iconName: String
        let iconColor: Color
        switch action {
        case .like where viewModel.isLiked:
            iconName = "heart.fill"
            iconColor = .red
        case .pinToProfile where viewModel.isPinned:
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
                guard !viewModel.isPressing else { return }
                viewModel.currentZoom = value.magnification - 1
            }
            .onEnded { _ in
                guard !viewModel.isPressing else { return }
                viewModel.totalZoom = viewModel.effectiveZoom
                viewModel.currentZoom = 0
                if viewModel.totalZoom <= 1.05 {
                    viewModel.resetZoom()
                } else {
                    let clamped = viewModel.clampedOffset(viewModel.offset, zoom: viewModel.totalZoom)
                    if clamped != viewModel.offset {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            viewModel.offset = clamped
                            viewModel.lastOffset = clamped
                        }
                    }
                }
            }

        let drag = DragGesture()
            .onChanged { value in
                guard !viewModel.isPressing, viewModel.effectiveZoom > 1 else { return }
                let proposed = CGSize(
                    width: viewModel.lastOffset.width + value.translation.width,
                    height: viewModel.lastOffset.height + value.translation.height
                )
                viewModel.offset = viewModel.clampedOffset(proposed, zoom: viewModel.effectiveZoom)
            }
            .onEnded { _ in
                guard !viewModel.isPressing else { return }
                viewModel.lastOffset = viewModel.offset
            }

        return pinch.simultaneously(with: drag)
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
                    viewModel.handlePressBegan()
                case .second(true, let drag):
                    if !viewModel.isPressing {
                        viewModel.handlePressBegan()
                    }
                    viewModel.dragLocation = drag?.location
                default:
                    break
                }
            }
            .onEnded { _ in
                if let action = viewModel.hoveredAction {
                    viewModel.performAction(action, store: store)
                }
            }
    }
}

// MARK: - Preview

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
