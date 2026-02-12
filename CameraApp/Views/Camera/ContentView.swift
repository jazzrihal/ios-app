import SwiftUI

struct ContentView: View {
    @State private var capturedImage: UIImage?
    @State private var showCamera = false
    @State private var savedNotice = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                if let capturedImage {
                    Image(uiImage: capturedImage)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
                        .padding(.horizontal, 24)
                        .transition(.scale.combined(with: .opacity))

                    Button {
                        showCamera = true
                    } label: {
                        Label("Retake", systemImage: "arrow.triangle.2.circlepath.camera")
                            .font(.headline)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                } else {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.secondary)

                    Text("Tap the button below to take a picture")
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    showCamera = true
                } label: {
                    Label("Take Picture", systemImage: "camera.fill")
                        .font(.title3.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.blue)
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
            }
            .navigationTitle("Camera")
            .animation(.easeInOut, value: capturedImage != nil)
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker(image: $capturedImage)
                    .ignoresSafeArea()
            }
            .onChange(of: capturedImage) {
                guard let image = capturedImage else { return }
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                savedNotice = true
            }
            .overlay(alignment: .top) {
                if savedNotice {
                    Text("Photo saved to library")
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.thinMaterial, in: Capsule())
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .task {
                            try? await Task.sleep(for: .seconds(2))
                            withAnimation { savedNotice = false }
                        }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
