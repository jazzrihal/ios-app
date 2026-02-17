import SwiftUI
import UIKit

// MARK: - Camera Flow View (manages camera → choice → preview transition)

struct CameraFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthManager.self) private var authManager
    @Environment(UploadManager.self) private var uploadManager

    @State private var capturedPhoto: CapturedPhoto?
    @State private var showPostPreview = false
    @State private var locationManager = PostLocationManager()

    private var sourceType: UIImagePickerController.SourceType {
        #if targetEnvironment(simulator)
            .photoLibrary
        #else
            .camera
        #endif
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            CameraPicker(
                sourceType: sourceType,
                onCapture: { image in
                    capturedPhoto = CapturedPhoto(image: image)
                },
                onCancel: { dismiss() }
            )
            .ignoresSafeArea()

            pendingBadge
        }
        .fullScreenCover(item: $capturedPhoto) { photo in
            PhotoChoiceOverlay(
                image: photo.image,
                locationManager: locationManager,
                onEditPost: {
                    showPostPreview = true
                },
                onPostWithoutEditing: {
                    enqueueWithDefaults(image: photo.image)
                    capturedPhoto = nil
                },
                onDiscard: {
                    capturedPhoto = nil
                },
                onClose: {
                    dismiss()
                }
            )
            .fullScreenCover(isPresented: $showPostPreview) {
                PostPreviewView(
                    image: photo.image,
                    onDiscard: {
                        showPostPreview = false
                    },
                    onPost: {
                        dismiss()
                    }
                )
            }
        }
        .onAppear {
            locationManager.requestLocation()
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

    // MARK: - Post Later

    private func enqueueWithDefaults(image: UIImage) {
        guard let userId = authManager.userId else { return }
        let input = PostEnqueueInput(
            image: image,
            caption: nil,
            latitude: locationManager.coordinate?.latitude ?? 0,
            longitude: locationManager.coordinate?.longitude ?? 0,
            locationName: locationManager.locationName,
            scope: PostScope.friends.databaseValue,
            userId: userId
        )
        uploadManager.enqueue(input)
    }
}
