import SwiftUI

// MARK: - Camera Viewfinder

struct CameraViewfinderView: View {
    let camera: CameraModel
    let onCapture: (UIImage) -> Void
    let onCancel: () -> Void

    @State private var isCapturing = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            CameraPreviewRepresentable(session: camera.session)
                .ignoresSafeArea()

            if camera.isCameraUnavailable {
                VStack(spacing: 12) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.white.opacity(0.5))
                    Text("Camera not available")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }

            VStack {
                // Top bar
                HStack {
                    Button(action: onCancel) {
                        Image(systemName: "xmark")
                            .font(.title2.weight(.medium))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(.black.opacity(0.5), in: Circle())
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Spacer()

                // Capture button
                Button {
                    guard !isCapturing else { return }
                    isCapturing = true
                    Task {
                        if let image = await camera.capturePhoto() {
                            onCapture(image)
                        }
                        isCapturing = false
                    }
                } label: {
                    ZStack {
                        Circle()
                            .stroke(.white, lineWidth: 5)
                            .frame(width: 78, height: 78)
                        Circle()
                            .fill(.white)
                            .frame(width: 64, height: 64)
                    }
                    .scaleEffect(isCapturing ? 0.9 : 1.0)
                    .animation(.easeInOut(duration: 0.1), value: isCapturing)
                }
                .disabled(isCapturing || camera.isCameraUnavailable)
                .padding(.bottom, 50)
            }
        }
        .statusBarHidden()
    }
}
