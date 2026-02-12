import CoreLocation
import SwiftUI

// MARK: - Post Preview View

struct PostPreviewView: View {
    let image: UIImage
    let onDiscard: () -> Void
    let onPost: () -> Void

    @Environment(AuthManager.self) private var authManager
    @State private var caption = ""
    @State private var captureDate = Date()
    @State private var scope: PostScope = .friends
    @State private var locationManager = PostLocationManager()
    @State private var isUploading = false
    @State private var uploadError: String?
    @FocusState private var captionFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    imagePreviewSection
                    captionSection
                    dateTimeSection
                    locationSection
                    scopeSection

                    if let uploadError {
                        Text(uploadError)
                            .font(.caption)
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 16)
                    }

                    postButton
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .ignoresSafeArea(edges: .top)
            .navigationTitle("New Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Discard") {
                        onDiscard()
                    }
                    .accessibilityIdentifier("DiscardButton")
                    .foregroundStyle(.primary)
                    .disabled(isUploading)
                }
            }
        }
        .onAppear {
            locationManager.requestLocation()
        }
    }

    // MARK: - Subviews

    private var imagePreviewSection: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity)
            .clipped()
    }

    private var captionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Caption", systemImage: "text.bubble")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            TextField("Write a caption…", text: $caption, axis: .vertical)
                .accessibilityIdentifier("CaptionTextField")
                .lineLimit(3 ... 6)
                .padding(12)
                .background(
                    .ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: 10)
                )
                .focused($captionFocused)
        }
        .padding(.horizontal, 16)
    }

    private var dateTimeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Date & Time", systemImage: "calendar.badge.clock")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Image(systemName: "clock.fill")
                    .foregroundStyle(.primary)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(dateString)
                        .font(.subheadline.weight(.medium))
                    Text(timeString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(12)
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: 10)
            )
        }
        .padding(.horizontal, 16)
    }

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Location", systemImage: "location.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                locationContent
                Spacer()
            }
            .padding(12)
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: 10)
            )
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder private var locationContent: some View {
        if locationManager.isLoading {
            ProgressView()
                .controlSize(.small)
            Text("Getting location…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else if let name = locationManager.locationName {
            Image(systemName: "mappin.circle.fill")
                .foregroundStyle(.primary)
                .font(.title3)
            Text(name)
                .font(.subheadline)
        } else {
            Image(systemName: "location.slash.fill")
                .foregroundStyle(.secondary)
                .font(.title3)
            Text("Location unavailable")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var scopeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Who can see this?", systemImage: "eye")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 0) {
                ForEach(PostScope.allCases) { option in
                    ScopeOptionButton(
                        option: option,
                        isSelected: scope == option
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            scope = option
                        }
                    }
                }
            }
            .padding(4)
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: 10)
            )
        }
        .padding(.horizontal, 16)
    }

    private var postButton: some View {
        Button {
            uploadAndPost()
        } label: {
            Group {
                if isUploading {
                    ProgressView()
                        .tint(Color(.systemGray))
                } else {
                    Text("Post")
                        .font(.headline)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(isUploading ? Color(.systemGray) : Color(.systemBackground))
            .background(isUploading ? Color(.systemGray5) : Color.primary, in: RoundedRectangle(cornerRadius: 10))
        }
        .accessibilityIdentifier("PostButton")
        .buttonStyle(.plain)
        .disabled(isUploading)
        .padding(.horizontal, 16)
        .padding(.bottom, 32)
    }

    // MARK: - Upload Logic

    private func uploadAndPost() {
        guard let userId = authManager.userId else {
            uploadError = "Not signed in."
            return
        }

        isUploading = true
        uploadError = nil

        Task {
            do {
                let postId = UUID()
                guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                    throw PostUploadError.imageConversion
                }

                // 1. Upload image to Storage
                let storagePath = "\(userId)/\(postId).jpg"
                try await SupabaseManager.client.storage
                    .from("post-images")
                    .upload(storagePath, data: imageData, options: .init(contentType: "image/jpeg"))

                // 2. Insert post row directly
                let coord = locationManager.coordinate
                let insert = PublicSchema.PostsInsert(
                    caption: caption.isEmpty ? nil : caption,
                    createdAt: nil,
                    id: postId,
                    imagePath: storagePath,
                    latitude: coord?.latitude ?? 0,
                    location: nil,
                    locationName: locationManager.locationName,
                    longitude: coord?.longitude ?? 0,
                    scope: scope.databaseValue,
                    userId: userId
                )
                try await SupabaseManager.client.from("posts").insert(insert).execute()

                // Success — dismiss
                await MainActor.run { onPost() }
            } catch {
                uploadError = error.localizedDescription
                isUploading = false
            }
        }
    }

    // MARK: - Helpers

    private var dateString: String {
        captureDate.formatted(
            .dateTime.weekday(.wide).month(.wide).day().year()
        )
    }

    private var timeString: String {
        captureDate.formatted(
            .dateTime.hour().minute().second()
        )
    }
}

// MARK: - Errors

private enum PostUploadError: LocalizedError {
    case imageConversion

    var errorDescription: String? {
        switch self {
        case .imageConversion: "Failed to compress image."
        }
    }
}

// MARK: - Scope Option Button

struct ScopeOptionButton: View {
    let option: PostScope
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: option.icon)
                    .font(.title3)
                Text(option.rawValue)
                    .font(.caption.weight(.semibold))
                Text(option.subtitle)
                    .font(.caption2)
                    .foregroundStyle(
                        isSelected ? Color.primary.opacity(0.8) : Color.gray.opacity(0.4)
                    )
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                isSelected ? Color.primary.opacity(0.12) : Color.clear,
                in: RoundedRectangle(cornerRadius: 10)
            )
            .foregroundStyle(isSelected ? .primary : .secondary)
        }
        .buttonStyle(.plain)
    }
}
