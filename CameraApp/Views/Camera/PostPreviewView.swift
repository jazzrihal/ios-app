import CoreLocation
import SwiftUI

// MARK: - Post Preview View

struct PostPreviewView: View {
    let image: UIImage
    let onDone: () -> Void

    @Environment(AuthManager.self) private var authManager
    @Environment(UploadManager.self) private var uploadManager
    @Environment(NetworkMonitor.self) private var networkMonitor
    @State private var caption = ""
    @State private var captureDate = Date()
    @State private var scope: PostScope = .friends
    @State private var locationManager = PostLocationManager()
    @State private var enqueueError: String?
    @FocusState private var captionFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    imageSection
                    quickActionsSection
                    offlineBanner
                    captionSection
                    dateTimeSection
                    locationSection
                    scopeSection

                    if let enqueueError {
                        Text(enqueueError)
                            .font(.caption)
                            .foregroundStyle(.red)
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
                        onDone()
                    }
                    .accessibilityIdentifier("DiscardButton")
                    .foregroundStyle(.primary)
                }
            }
        }
        .onAppear {
            locationManager.requestLocation()
        }
    }

    // MARK: - Image

    private var imageSection: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity)
            .clipped()
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(spacing: 12) {
            Button {
                enqueueWithDefaults()
            } label: {
                Label("Post Without Editing", systemImage: "paperplane.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(Color(.systemBackground))
                    .background(Color.primary, in: RoundedRectangle(cornerRadius: 10))
            }
            .accessibilityIdentifier("PostWithoutEditingButton")
            .buttonStyle(.plain)

            Button {
                saveDraft()
            } label: {
                Label("Save Without Uploading", systemImage: "square.and.arrow.down")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(.primary)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
            }
            .accessibilityIdentifier("SaveWithoutUploadingButton")
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Offline Banner

    @ViewBuilder private var offlineBanner: some View {
        if !networkMonitor.isConnected {
            HStack(spacing: 10) {
                Image(systemName: "wifi.slash")
                    .font(.title3)
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("You are offline")
                        .font(.subheadline.weight(.semibold))
                    Text("Save your photo and upload when you're back online.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(12)
            .background(
                Color.orange.opacity(0.1),
                in: RoundedRectangle(cornerRadius: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
            )
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Caption

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

    // MARK: - Date & Time

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

    // MARK: - Location

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

    // MARK: - Scope

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

    // MARK: - Post Button

    private var postButton: some View {
        Button {
            enqueueWithSettings()
        } label: {
            Text("Post")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(Color(.systemBackground))
                .background(Color.primary, in: RoundedRectangle(cornerRadius: 10))
        }
        .accessibilityIdentifier("PostButton")
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.bottom, 32)
    }

    // MARK: - Actions

    private func enqueueWithDefaults() {
        guard let userId = authManager.userId else {
            enqueueError = "Not signed in."
            return
        }

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
        onDone()
    }

    private func saveDraft() {
        guard let userId = authManager.userId else {
            enqueueError = "Not signed in."
            return
        }

        let input = PostEnqueueInput(
            image: image,
            caption: caption.isEmpty ? nil : caption,
            latitude: locationManager.coordinate?.latitude ?? 0,
            longitude: locationManager.coordinate?.longitude ?? 0,
            locationName: locationManager.locationName,
            scope: scope.databaseValue,
            userId: userId
        )
        uploadManager.saveDraft(input)
        onDone()
    }

    private func enqueueWithSettings() {
        guard let userId = authManager.userId else {
            enqueueError = "Not signed in."
            return
        }

        let input = PostEnqueueInput(
            image: image,
            caption: caption.isEmpty ? nil : caption,
            latitude: locationManager.coordinate?.latitude ?? 0,
            longitude: locationManager.coordinate?.longitude ?? 0,
            locationName: locationManager.locationName,
            scope: scope.databaseValue,
            userId: userId
        )
        uploadManager.enqueue(input)
        onDone()
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
