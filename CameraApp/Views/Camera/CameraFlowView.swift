import SwiftUI

// MARK: - Camera Flow View (manages camera → preview transition)

struct CameraFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var capturedPhoto: CapturedPhoto?
    @State private var camera = CameraModel()

    var body: some View {
        cameraView
            .fullScreenCover(item: $capturedPhoto) { photo in
                PostPreviewView(
                    image: photo.image,
                    onDiscard: {
                        capturedPhoto = nil
                        #if !targetEnvironment(simulator)
                            camera.startSession()
                        #endif
                    },
                    onPost: {
                        #if !targetEnvironment(simulator)
                            camera.stopSession()
                        #endif
                        dismiss()
                    }
                )
            }
    }

    @ViewBuilder private var cameraView: some View {
        #if targetEnvironment(simulator)
            SimulatorCameraView(
                onCapture: { image in
                    capturedPhoto = CapturedPhoto(image: image)
                },
                onCancel: { dismiss() }
            )
        #else
            CameraViewfinderView(
                camera: camera,
                onCapture: { image in
                    camera.stopSession()
                    capturedPhoto = CapturedPhoto(image: image)
                },
                onCancel: {
                    camera.stopSession()
                    dismiss()
                }
            )
            .onAppear {
                camera.configure()
                camera.startSession()
            }
        #endif
    }
}
