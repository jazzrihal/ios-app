import AVFoundation
import SwiftUI
import UIKit

// MARK: - Custom Camera View

struct CustomCameraView: View {
    let onCapture: (UIImage) -> Void
    let onCancel: () -> Void

    #if !targetEnvironment(simulator)
        @State private var cameraService = CameraService()
    #endif

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            #if targetEnvironment(simulator)
                simulatorPlaceholder
            #else
                CameraPreviewRepresentable(session: cameraService.session)
                    .ignoresSafeArea()
            #endif

            cameraOverlay
        }
        #if !targetEnvironment(simulator)
        .onAppear { cameraService.start() }
        .onDisappear { cameraService.stop() }
        #endif
    }

    // MARK: - Overlay (shared on both platforms)

    private var cameraOverlay: some View {
        VStack {
            HStack {
                Button {
                    onCancel()
                } label: {
                    Image(systemName: "xmark")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.white.opacity(0.2), in: Circle())
                }
                .accessibilityIdentifier("CameraCloseButton")

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            Spacer()

            captureButton
                .padding(.bottom, 40)
        }
    }

    private var captureButton: some View {
        Button {
            performCapture()
        } label: {
            ZStack {
                Circle()
                    .stroke(.white, lineWidth: 4)
                    .frame(width: 72, height: 72)
                Circle()
                    .fill(.white)
                    .frame(width: 60, height: 60)
            }
        }
        .accessibilityIdentifier("CaptureButton")
        .accessibilityLabel("Take photo")
    }

    #if targetEnvironment(simulator)
        private var simulatorPlaceholder: some View {
            VStack(spacing: 12) {
                Image(systemName: "camera")
                    .font(.system(size: 48))
                    .foregroundStyle(.white.opacity(0.3))
                Text("Simulator Camera")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
    #endif

    // MARK: - Capture

    private func performCapture() {
        #if targetEnvironment(simulator)
            onCapture(generateTimestampImage())
        #else
            cameraService.capturePhoto { image in
                if let image {
                    onCapture(image)
                }
            }
        #endif
    }

    #if targetEnvironment(simulator)
        private func generateTimestampImage() -> UIImage {
            let size = CGSize(width: 1170, height: 1560)
            let renderer = UIGraphicsImageRenderer(size: size)

            return renderer.image { context in
                UIColor.black.setFill()
                context.fill(CGRect(origin: .zero, size: size))

                let timestamp = Date().formatted(
                    .dateTime.year().month().day().hour().minute().second()
                )
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.monospacedSystemFont(ofSize: 32, weight: .medium),
                    .foregroundColor: UIColor.white,
                ]
                let string = NSAttributedString(string: timestamp, attributes: attributes)
                let textSize = string.size()
                let textOrigin = CGPoint(
                    x: (size.width - textSize.width) / 2,
                    y: (size.height - textSize.height) / 2
                )
                string.draw(at: textOrigin)
            }
        }
    #endif
}

// MARK: - Camera Service (AVFoundation, device only)

#if !targetEnvironment(simulator)
    @Observable
    final class CameraService: NSObject, AVCapturePhotoCaptureDelegate {
        let session = AVCaptureSession()
        private let photoOutput = AVCapturePhotoOutput()
        private var captureCompletion: ((UIImage?) -> Void)?

        func start() {
            guard session.inputs.isEmpty else { return }

            session.beginConfiguration()
            session.sessionPreset = .photo

            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(input)
            else {
                session.commitConfiguration()
                return
            }

            session.addInput(input)

            guard session.canAddOutput(photoOutput) else {
                session.commitConfiguration()
                return
            }

            session.addOutput(photoOutput)
            session.commitConfiguration()

            DispatchQueue.global(qos: .userInitiated).async { [session] in
                session.startRunning()
            }
        }

        func stop() {
            DispatchQueue.global(qos: .userInitiated).async { [session] in
                session.stopRunning()
            }
        }

        func capturePhoto(completion: @escaping (UIImage?) -> Void) {
            captureCompletion = completion
            let settings = AVCapturePhotoSettings()
            photoOutput.capturePhoto(with: settings, delegate: self)
        }

        func photoOutput(
            _ output: AVCapturePhotoOutput,
            didFinishProcessingPhoto photo: AVCapturePhoto,
            error: Error?
        ) {
            let image: UIImage? = if let data = photo.fileDataRepresentation() {
                UIImage(data: data)
            } else {
                nil
            }
            Task { @MainActor in
                captureCompletion?(image)
                captureCompletion = nil
            }
        }
    }
#endif

// MARK: - Camera Preview (UIViewRepresentable, device only)

#if !targetEnvironment(simulator)
    struct CameraPreviewRepresentable: UIViewRepresentable {
        let session: AVCaptureSession

        func makeUIView(context: Context) -> CameraPreviewUIView {
            let view = CameraPreviewUIView()
            view.previewLayer.session = session
            return view
        }

        func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {}
    }

    final class CameraPreviewUIView: UIView {
        override static var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }

        var previewLayer: AVCaptureVideoPreviewLayer {
            // swiftlint:disable:next force_cast
            layer as! AVCaptureVideoPreviewLayer
        }

        override init(frame: CGRect) {
            super.init(frame: frame)
            previewLayer.videoGravity = .resizeAspectFill
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
#endif
