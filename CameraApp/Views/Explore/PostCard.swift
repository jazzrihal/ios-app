import SwiftUI

// MARK: - Post Card

struct PostCard: View {
    let post: ImagePost
    let queryDate: Date
    var onTapProfile: () -> Void
    var onTapPost: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // User header (above photo) — navigates to profile
            Button {
                onTapProfile()
            } label: {
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
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            // Image — tappable to open post detail
            Button {
                onTapPost()
            } label: {
                AsyncImage(url: post.imageURL) { phase in
                    switch phase {
                    case .empty:
                        ZStack {
                            Rectangle()
                                .fill(Color(.systemGray5))
                            ProgressView()
                        }
                    case let .success(image):
                        image
                            .resizable()
                            .scaledToFill()
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
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .clipped()
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Info below photo
            VStack(alignment: .leading, spacing: 6) {
                // Metadata row (closest to photo)
                HStack(spacing: 16) {
                    Label(post.timeAgoFormatted, systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Label(post.locationName, systemImage: "mappin")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                // Caption
                Text(post.caption)
                    .font(.body)
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(.background)
    }
}
