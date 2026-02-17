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
                // Photo mosaic
                if !posts.isEmpty {
                    photoMosaic
                }

                // Info footer
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(moment.locationName)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)

                        HStack(spacing: 10) {
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

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
        }
        .buttonStyle(MomentCardButtonStyle())
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
            HStack(spacing: 2) {
                thumbnailImage(for: posts[0])
                thumbnailImage(for: posts[1])
            }
            .frame(height: height)
            .clipped()
        } else {
            HStack(spacing: 2) {
                thumbnailImage(for: posts[0])
                    .frame(maxWidth: .infinity)

                VStack(spacing: 2) {
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
        LazyImage(url: post.imageURL) { state in
            if let image = state.image {
                Color.clear
                    .overlay {
                        image
                            .resizable()
                            .scaledToFill()
                    }
                    .clipped()
            } else if state.error != nil {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.quaternary)
                    }
            } else {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .overlay { ProgressView().tint(.secondary) }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Card Button Style

/// Provides a subtle scale + opacity press effect for the moment card.
struct MomentCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}
