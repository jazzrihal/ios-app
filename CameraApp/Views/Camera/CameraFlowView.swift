import SwiftUI

// MARK: - Camera Flow View

struct CameraFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(UploadManager.self) private var uploadManager

    @State private var capturedPhoto: CapturedPhoto?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            CustomCameraView(
                onCapture: { image in
                    capturedPhoto = CapturedPhoto(image: image)
                },
                onCancel: { dismiss() }
            )

            pendingBadge
        }
        .fullScreenCover(item: $capturedPhoto) { photo in
            PostPreviewView(
                image: photo.image,
                onDone: { capturedPhoto = nil }
            )
        }
    }

    // MARK: - Pending Badge

    @ViewBuilder private var pendingBadge: some View {
        let count = uploadManager.pendingPosts.count
        if count > 0 {
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.caption2)
                Text("\(count)")
                    .font(.caption2.weight(.bold))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(.top, 60)
            .padding(.trailing, 16)
        }
    }
}
