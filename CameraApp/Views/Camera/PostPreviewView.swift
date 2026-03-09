import CoreLocation
import SwiftUI

// MARK: - Post Preview View

struct PostPreviewView: View {
    enum Mode {
        case create(image: UIImage)
        case edit(existingPost: ImagePost)
    }

    private let mode: Mode
    let onDone: () -> Void
    let onSaved: (() -> Void)?

    @Environment(AuthManager.self) private var authManager
    @Environment(UploadManager.self) private var uploadManager
    @Environment(NetworkMonitor.self) private var networkMonitor
    @Environment(DefaultPostRepository.self) private var postRepository
    @Environment(CacheInvalidator.self) private var cacheInvalidator
    @State private var caption: String
    @State private var captureDate: Date
    @State private var scope: PostScope
    @State private var fixedLocationName: String?
    @State private var locationManager = PostLocationManager()
    @State private var enqueueError: String?
    @State private var isSavingEdits = false
    @FocusState private var captionFocused: Bool

    init(image: UIImage, onDone: @escaping () -> Void) {
        mode = .create(image: image)
        self.onDone = onDone
        onSaved = nil
        _caption = State(initialValue: "")
        _captureDate = State(initialValue: Date())
        _scope = State(initialValue: .friends)
        _fixedLocationName = State(initialValue: nil)
    }

    init(
        editingPost: ImagePost,
        onDone: @escaping () -> Void,
        onSaved: (() -> Void)? = nil
    ) {
        mode = .edit(existingPost: editingPost)
        self.onDone = onDone
        self.onSaved = onSaved
        _caption = State(initialValue: editingPost.caption)
        _captureDate = State(initialValue: editingPost.timestamp)
        _scope = State(initialValue: editingPost.scope)
        _fixedLocationName = State(initialValue: editingPost.locationName)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppStyle.Spacing.large) {
                    imageSection
                    if isCreateMode {
                        quickActionsSection
                        offlineBanner
                    }
                    captionSection
                    dateTimeSection
                    locationSection
                    if !isCreateMode {
                        Text("Photo, location, and timestamp cannot be changed.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, AppStyle.Padding.screenHorizontal)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityIdentifier("ImmutablePostMetadataNotice")
                    }
                    scopeSection

                    if let enqueueError {
                        Text(enqueueError)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal, AppStyle.Padding.screenHorizontal)
                    }

                    postButton
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .ignoresSafeArea(edges: .top)
            .navigationTitle(isCreateMode ? "New Post" : "Edit Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isCreateMode ? "Discard" : "Cancel") {
                        onDone()
                    }
                    .accessibilityIdentifier("DiscardButton")
                    .foregroundStyle(.primary)
                }
            }
        }
        .onAppear {
            if isCreateMode {
                locationManager.requestLocation()
            }
        }
    }

    // MARK: - Image

    private var imageSection: some View {
        Group {
            switch mode {
            case let .create(image):
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .clipped()
            case let .edit(existingPost):
                RemoteImage(url: existingPost.imageURL, contentMode: .fit)
            }
        }
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        HStack(spacing: AppStyle.Spacing.large) {
            Button {
                enqueueWithDefaults()
            } label: {
                Label("Post Without Editing", systemImage: "paperplane")
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
            .accessibilityIdentifier("PostWithoutEditingButton")

            Button {
                saveDraft()
            } label: {
                Label("Save Without Uploading", systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
            .accessibilityIdentifier("SaveWithoutUploadingButton")
        }
        .buttonStyle(.appText)
        .padding(.horizontal, AppStyle.Padding.screenHorizontal)
    }

    // MARK: - Offline Banner

    @ViewBuilder private var offlineBanner: some View {
        if !networkMonitor.isConnected {
            HStack(spacing: AppStyle.Spacing.row) {
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
            .padding(AppStyle.Padding.cardInner)
            .background(
                Color.orange.opacity(0.1),
                in: RoundedRectangle(cornerRadius: AppStyle.CornerRadius.control)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppStyle.CornerRadius.control)
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
            )
            .padding(.horizontal, AppStyle.Padding.screenHorizontal)
        }
    }

    // MARK: - Caption

    private var captionSection: some View {
        VStack(alignment: .leading, spacing: AppStyle.Spacing.small) {
            Label("Caption", systemImage: "text.bubble")
                .sectionLabel()

            TextField("Write a caption…", text: $caption, axis: .vertical)
                .accessibilityIdentifier("CaptionTextField")
                .lineLimit(3 ... 6)
                .padding(AppStyle.Padding.cardInner)
                .background(
                    .ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: AppStyle.CornerRadius.control)
                )
                .focused($captionFocused)
        }
        .padding(.horizontal, AppStyle.Padding.screenHorizontal)
    }

    // MARK: - Date & Time

    private var dateTimeSection: some View {
        VStack(alignment: .leading, spacing: AppStyle.Spacing.small) {
            Label("Date & Time", systemImage: "calendar.badge.clock")
                .sectionLabel()

            HStack(spacing: AppStyle.Spacing.row) {
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
            .padding(AppStyle.Padding.cardInner)
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: AppStyle.CornerRadius.control)
            )
        }
        .padding(.horizontal, AppStyle.Padding.screenHorizontal)
    }

    // MARK: - Location

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: AppStyle.Spacing.small) {
            Label("Location", systemImage: "location.fill")
                .sectionLabel()

            HStack(spacing: AppStyle.Spacing.row) {
                locationContent
                Spacer()
            }
            .padding(AppStyle.Padding.cardInner)
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: AppStyle.CornerRadius.control)
            )
        }
        .padding(.horizontal, AppStyle.Padding.screenHorizontal)
    }

    @ViewBuilder private var locationContent: some View {
        if isCreateMode {
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
        } else if let fixedLocationName, !fixedLocationName.isEmpty {
            Image(systemName: "mappin.circle.fill")
                .foregroundStyle(.primary)
                .font(.title3)
            Text(fixedLocationName)
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
        VStack(alignment: .leading, spacing: AppStyle.Spacing.small) {
            Label("Who can see this?", systemImage: "eye")
                .sectionLabel()

            HStack(spacing: 0) {
                ForEach(PostScope.allCases) { option in
                    ScopeOptionButton(
                        option: option,
                        isSelected: scope == option
                    ) {
                        withAnimation(AppStyle.Animation.transition) {
                            scope = option
                        }
                    }
                }
            }
            .padding(AppStyle.Spacing.tight)
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: AppStyle.CornerRadius.control)
            )
        }
        .padding(.horizontal, AppStyle.Padding.screenHorizontal)
    }

    // MARK: - Post Button

    private var postButton: some View {
        Button {
            if isCreateMode {
                enqueueWithSettings()
            } else {
                Task { await saveEdits() }
            }
        } label: {
            Text(isCreateMode ? "Post" : "Save Changes")
        }
        .accessibilityIdentifier(isCreateMode ? "PostButton" : "SavePostChangesButton")
        .buttonStyle(.appPrimary)
        .padding(.horizontal, AppStyle.Padding.screenHorizontal)
        .padding(.bottom, 32)
        .disabled(isSavingEdits)
    }

    // MARK: - Actions

    private func enqueueWithDefaults() {
        guard let image = createImage else {
            enqueueError = "Unable to prepare image."
            return
        }
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
        guard let image = createImage else {
            enqueueError = "Unable to prepare image."
            return
        }
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
        guard let image = createImage else {
            enqueueError = "Unable to prepare image."
            return
        }
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

    @MainActor
    private func saveEdits() async {
        guard case let .edit(existingPost) = mode else { return }
        guard authManager.userId != nil else {
            enqueueError = "Not signed in."
            return
        }

        enqueueError = nil
        isSavingEdits = true
        defer { isSavingEdits = false }

        do {
            let trimmedCaption = caption.trimmingCharacters(in: .whitespacesAndNewlines)
            try await postRepository.updatePost(
                id: existingPost.id,
                caption: trimmedCaption.isEmpty ? nil : trimmedCaption,
                scope: scope
            )
            cacheInvalidator.postEdited(userId: existingPost.user.id)
            onSaved?()
            onDone()
        } catch {
            enqueueError = "Failed to save changes. Please try again."
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

    private var isCreateMode: Bool {
        if case .create = mode { return true }
        return false
    }

    private var createImage: UIImage? {
        guard case let .create(image) = mode else { return nil }
        return image
    }
}

// MARK: - Scope Option Button

struct ScopeOptionButton: View {
    let option: PostScope
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: AppStyle.Spacing.compact) {
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
            .padding(.vertical, AppStyle.Padding.cardInner)
            .background(
                isSelected ? Color.primary.opacity(0.12) : Color.clear,
                in: RoundedRectangle(cornerRadius: AppStyle.CornerRadius.control)
            )
            .foregroundStyle(isSelected ? .primary : .secondary)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("ScopeOption_\(option.rawValue)")
    }
}
