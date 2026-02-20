import NukeUI
import SwiftUI

// MARK: - Post Card

struct PostCard: View {
    let post: ImagePost
    let queryDate: Date
    var onTapProfile: () -> Void
    var onTapPost: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                onTapProfile()
            } label: {
                HStack(spacing: AppStyle.Spacing.row) {
                    AvatarView(user: post.user, size: AppStyle.IconSize.avatarSmall)

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
            .padding(.horizontal, AppStyle.Padding.screenHorizontal)
            .padding(.vertical, AppStyle.Spacing.small)

            Button {
                onTapPost()
            } label: {
                RemoteImage(url: post.imageURL)
                    .frame(maxWidth: .infinity)
                    .frame(height: 260)
                    .clipped()
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: AppStyle.Spacing.compact) {
                HStack(spacing: AppStyle.Padding.screenHorizontal) {
                    Label(post.timeAgoFormatted, systemImage: "clock")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Label(post.locationName, systemImage: "mappin")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
            .padding(.horizontal, AppStyle.Padding.screenHorizontal)
            .padding(.vertical, AppStyle.Spacing.small)
        }
        .background(.background)
    }
}
