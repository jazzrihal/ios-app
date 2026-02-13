import SwiftUI
import UIKit

// MARK: - Camera Flow View (manages camera → preview transition)

struct CameraFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var capturedPhoto: CapturedPhoto?

    private var sourceType: UIImagePickerController.SourceType {
        #if targetEnvironment(simulator)
            .photoLibrary
        #else
            .camera
        #endif
    }

    var body: some View {
        CameraPicker(
            sourceType: sourceType,
            onCapture: { image in
                capturedPhoto = CapturedPhoto(image: image)
            },
            onCancel: { dismiss() }
        )
        .ignoresSafeArea()
        .fullScreenCover(item: $capturedPhoto) { photo in
            PostPreviewView(
                image: photo.image,
                onDiscard: {
                    capturedPhoto = nil
                },
                onPost: {
                    dismiss()
                }
            )
        }
    }
}
