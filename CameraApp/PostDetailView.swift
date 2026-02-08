import SwiftUI

struct PostDetailView: View {
    let post: ImagePost
    let queryDate: Date

    @Environment(MomentsStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // ── Image ──
                postImage

                // ── Content ──
                VStack(alignment: .leading, spacing: 16) {
                    // ── User header ──
                    userHeader

                    Divider()

                    // ── Caption ──
                    captionSection

                    // ── Time info ──
                    timeSection

                    // ── Location info ──
                    locationSection

                    // ── Explore here button ──
                    exploreHereButton
                }
                .padding(16)
            }
        }
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
                .frame(minHeight: 320)
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 320)
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
                .frame(minHeight: 320)
            @unknown default:
                EmptyView()
            }
        }
    }

    // MARK: - User Header

    private var userHeader: some View {
        NavigationLink(destination: FriendProfileView(user: post.user)) {
            HStack(spacing: 12) {
                AvatarView(user: post.user, size: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text(post.user.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text("@\(post.user.username)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Caption

    private var captionSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Caption", systemImage: "text.bubble")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(post.caption)
                .font(.body)
                .foregroundStyle(.primary)
        }
    }

    // MARK: - Time Info

    private var timeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Time", systemImage: "clock.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Image(systemName: "clock.fill")
                    .foregroundStyle(.blue)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(post.timeAgoFormatted)
                        .font(.subheadline.weight(.medium))
                    Text(post.timestamp.formatted(.dateTime.month(.wide).day().year().hour().minute()))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Location Info

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Location", systemImage: "location.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Image(systemName: "mappin.circle.fill")
                    .foregroundStyle(.red)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(post.locationName)
                        .font(.subheadline.weight(.medium))
                    Text(post.distanceFormatted)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
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
