import NukeUI
import SwiftUI

// MARK: - Moment Card

struct MomentCard: View {
    let moment: Moment
    let posts: [ImagePost]
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                if !posts.isEmpty {
                    photoMosaic
                }

                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: AppStyle.Spacing.tight) {
                        Text(moment.locationName)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)

                        HStack(spacing: AppStyle.Spacing.row) {
                            Label(moment.dateFormatted, systemImage: "calendar")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text("·")
                                .foregroundStyle(.quaternary)

                            Text("Saved \(moment.addedAtFormatted)")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Spacer(minLength: AppStyle.Spacing.small)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, AppStyle.Padding.cardInner)
                .padding(.vertical, AppStyle.Padding.cardInner)
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppStyle.CornerRadius.card, style: .continuous))
            .cardShadow()
        }
        .buttonStyle(.momentCard)
        .accessibilityIdentifier("MomentCard_\(moment.id.uuidString)")
    }

    // MARK: - Photo Mosaic

    @ViewBuilder private var photoMosaic: some View {
        let count = min(posts.count, 5)
        let height: CGFloat = 160

        if count == 1 {
            thumbnailImage(for: posts[0])
                .frame(height: height)
                .frame(maxWidth: .infinity)
                .clipped()
        } else if count == 2 {
            HStack(spacing: AppStyle.Spacing.grid) {
                thumbnailImage(for: posts[0])
                thumbnailImage(for: posts[1])
            }
            .frame(height: height)
            .clipped()
        } else {
            HStack(spacing: AppStyle.Spacing.grid) {
                thumbnailImage(for: posts[0])
                    .frame(maxWidth: .infinity)

                VStack(spacing: AppStyle.Spacing.grid) {
                    ForEach(posts[1 ..< count]) { post in
                        thumbnailImage(for: post)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .frame(height: height)
            .clipped()
        }
    }

    private func thumbnailImage(for post: ImagePost) -> some View {
        RemoteImage(url: post.imageURL)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
