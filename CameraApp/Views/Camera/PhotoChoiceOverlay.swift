import SwiftUI

// MARK: - Photo Choice Overlay

/// Shown after a photo is captured. Displays the image in the same style as
/// PostDetailView (scaledToFit on black) with action buttons at the bottom.
struct PhotoChoiceOverlay: View {
    let image: UIImage
    let locationManager: PostLocationManager
    let onEditPost: () -> Void
    let onPostWithoutEditing: () -> Void
    let onDiscard: () -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack {
                topBar
                Spacer()
                bottomActions
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button {
                onDiscard()
            } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .accessibilityIdentifier("ChoiceDiscardButton")

            Spacer()
        }
        .padding(.leading, 16)
        .padding(.top, 12)
    }

    // MARK: - Bottom Actions

    private var bottomActions: some View {
        VStack(spacing: 12) {
            locationLabel

            Button {
                onEditPost()
            } label: {
                Text("Edit Post")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(Color(.systemBackground))
                    .background(Color.primary, in: RoundedRectangle(cornerRadius: 10))
            }
            .accessibilityIdentifier("EditPostButton")
            .buttonStyle(.plain)

            Button {
                onPostWithoutEditing()
            } label: {
                Text("Post Without Editing")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(.white)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
            }
            .accessibilityIdentifier("PostWithoutEditingButton")
            .buttonStyle(.plain)

            Button {
                onClose()
            } label: {
                Text("Close Camera")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .accessibilityIdentifier("CloseCameraButton")
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 32)
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.5)],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
        )
    }

    // MARK: - Location Label

    @ViewBuilder private var locationLabel: some View {
        if let name = locationManager.locationName {
            HStack(spacing: 4) {
                Image(systemName: "mappin.circle.fill")
                    .font(.caption)
                Text(name)
                    .font(.caption)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
        } else if locationManager.isLoading {
            HStack(spacing: 4) {
                ProgressView()
                    .controlSize(.mini)
                    .tint(.white.opacity(0.7))
                Text("Getting location…")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
        }
    }
}
