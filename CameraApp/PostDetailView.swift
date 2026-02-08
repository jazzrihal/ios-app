import SwiftUI

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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // ── User header (above image) ──
                userHeader
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                // ── Image ──
                postImage

                // ── Info below image ──
                VStack(alignment: .leading, spacing: 12) {
                    metadataRow
                    Text(post.caption)
                        .font(.body)
                        .foregroundStyle(.primary)
                    exploreHereButton
                }
                .padding(16)
            }
        }
        .ignoresSafeArea(edges: .top)
        .navigationTitle("Post")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Post Image

    private var postImage: some View {
        AsyncImage(url: post.imageURL) { phase in
            switch phase {
            case .empty:
                ZStack {
                    Rectangle()
                        .fill(Color(.systemGray5))
                    ProgressView()
                }
                .frame(minHeight: 400)
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 400)
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
                    .onTapGesture(count: 2) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            if totalZoom > 1 {
                                // Reset to default
                                totalZoom = 1
                                currentZoom = 0
                                offset = .zero
                                lastOffset = .zero
                            } else {
                                // Zoom in to 3x
                                totalZoom = 3
                                currentZoom = 0
                            }
                        }
                    }
                    .clipped()
            case .failure:
                ZStack {
                    Rectangle()
                        .fill(Color(.systemGray5))
                    VStack(spacing: 6) {
                        Image(systemName: "photo.badge.exclamationmark")
                            .font(.title2)
                        Text("Failed to load")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
                .frame(minHeight: 400)
            @unknown default:
                EmptyView()
            }
        }
    }

    // MARK: - Zoom Gestures

    private var zoomGestures: some Gesture {
        let pinch = MagnifyGesture()
            .onChanged { value in
                currentZoom = value.magnification - 1
            }
            .onEnded { value in
                totalZoom = effectiveZoom
                currentZoom = 0
                if totalZoom <= 1.05 {
                    resetZoom()
                } else {
                    // Re-clamp offset for the new zoom level
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
                guard effectiveZoom > 1 else { return }
                let proposed = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
                offset = clampedOffset(proposed, zoom: effectiveZoom)
            }
            .onEnded { _ in
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

    // MARK: - User Header

    private var userHeader: some View {
        NavigationLink(destination: FriendProfileView(user: post.user)) {
            HStack(spacing: 8) {
                AvatarView(user: post.user, size: 28)

                Text(post.user.displayName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Metadata Row

    private var metadataRow: some View {
        HStack(spacing: 16) {
            Label(post.timeAgoFormatted, systemImage: "clock")
                .font(.caption)
                .foregroundStyle(.secondary)
            Label(post.locationName, systemImage: "mappin")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - Explore Here Button

    private var exploreHereButton: some View {
        Button {
            store.pendingMoment = Moment(
                date: post.timestamp,
                locationName: post.locationName,
                coordinate: post.coordinate,
                addedAt: Date()
            )
            store.selectedTab = 0
            dismiss()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                Text("Explore this Time & Place")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .tint(.blue)
    }
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
