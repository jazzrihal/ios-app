import SwiftUI
import UIKit

// MARK: - Simulator Camera View

struct SimulatorCameraView: View {
    let onCapture: (UIImage) -> Void
    let onCancel: () -> Void

    @State private var isFlashing = false

    var body: some View {
        ZStack {
            // Simulated viewfinder background
            LinearGradient(
                colors: [
                    Color(white: 0.12),
                    Color(white: 0.08),
                    Color(white: 0.15),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Grid overlay (rule of thirds)
            simulatorGrid

            // Center indicator
            VStack(spacing: 16) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 72, weight: .thin))
                    .foregroundStyle(.white.opacity(0.3))

                Text("Simulator Camera")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.white.opacity(0.5))

                Text("Tap the shutter to simulate a capture")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.3))
            }

            // Flash overlay
            if isFlashing {
                Color.white
                    .ignoresSafeArea()
                    .transition(.opacity)
            }

            // Controls
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

                    // Simulator badge
                    Text("SIMULATOR")
                        .font(.caption2.weight(.bold))
                        .tracking(1.5)
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.orange.opacity(0.15), in: Capsule())
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Spacer()

                // Capture button
                Button {
                    simulateCapture()
                } label: {
                    ZStack {
                        Circle()
                            .stroke(.white, lineWidth: 5)
                            .frame(width: 78, height: 78)
                        Circle()
                            .fill(.white)
                            .frame(width: 64, height: 64)
                    }
                }
                .padding(.bottom, 50)
            }
        }
        .statusBarHidden()
    }

    private var simulatorGrid: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            Path { path in
                // Vertical lines (thirds)
                path.move(to: CGPoint(x: w / 3, y: 0))
                path.addLine(to: CGPoint(x: w / 3, y: h))
                path.move(to: CGPoint(x: 2 * w / 3, y: 0))
                path.addLine(to: CGPoint(x: 2 * w / 3, y: h))
                // Horizontal lines (thirds)
                path.move(to: CGPoint(x: 0, y: h / 3))
                path.addLine(to: CGPoint(x: w, y: h / 3))
                path.move(to: CGPoint(x: 0, y: 2 * h / 3))
                path.addLine(to: CGPoint(x: w, y: 2 * h / 3))
            }
            .stroke(.white.opacity(0.1), lineWidth: 0.5)
        }
        .ignoresSafeArea()
    }

    private func simulateCapture() {
        // Flash animation
        withAnimation(.easeIn(duration: 0.05)) {
            isFlashing = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeOut(duration: 0.15)) {
                isFlashing = false
            }
        }

        // Generate a placeholder image after the flash
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            let image = generatePlaceholderImage()
            onCapture(image)
        }
    }

    private func generatePlaceholderImage() -> UIImage {
        let size = CGSize(width: 1200, height: 1600)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            // Gradient background
            let colors = [
                UIColor.systemBlue.withAlphaComponent(0.6).cgColor,
                UIColor.systemPurple.withAlphaComponent(0.6).cgColor,
                UIColor.systemTeal.withAlphaComponent(0.4).cgColor,
            ]
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors as CFArray,
                locations: [0, 0.5, 1]
            )!
            ctx.cgContext.drawLinearGradient(
                gradient,
                start: .zero,
                end: CGPoint(x: size.width, y: size.height),
                options: []
            )

            // Draw "Simulator Photo" text
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center

            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 42, weight: .medium),
                .foregroundColor: UIColor.white.withAlphaComponent(0.8),
                .paragraphStyle: paragraphStyle,
            ]

            let text = "Simulator Photo"
            let textRect = CGRect(
                x: 0,
                y: size.height / 2 - 30,
                width: size.width,
                height: 60
            )
            text.draw(in: textRect, withAttributes: attrs)

            // Draw timestamp
            let dateAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24, weight: .regular),
                .foregroundColor: UIColor.white.withAlphaComponent(0.5),
                .paragraphStyle: paragraphStyle,
            ]
            let dateText = Date().formatted(
                .dateTime.month(.wide).day().year().hour().minute()
            )
            let dateRect = CGRect(
                x: 0,
                y: size.height / 2 + 30,
                width: size.width,
                height: 40
            )
            dateText.draw(in: dateRect, withAttributes: dateAttrs)
        }
    }
}
