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
                HStack(spacing: 10) {
                    AvatarView(user: post.user, size: 32)

                    Text(post.user.displayName)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.primary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
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
                        Color.clear
                            .overlay {
                                image
                                    .resizable()
                                    .scaledToFill()
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
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 260)
                .clipped()
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Info below photo
            VStack(alignment: .leading, spacing: 6) {
                // Metadata row (closest to photo)
                HStack(spacing: 16) {
                    Label(post.timeAgoFormatted, systemImage: "clock")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Label(post.locationName, systemImage: "mappin")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(.background)
    }
}
