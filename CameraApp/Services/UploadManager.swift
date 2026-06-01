import Foundation
import Observation
import OSLog
import Supabase
import UIKit

// MARK: - Upload Manager

/// Manages a persistent queue of post uploads with background retry support.
///
/// Injected into the SwiftUI environment. Views observe `pendingPosts` and
/// `completedUploadCount` to render pending upload status in the profile grid
/// and refresh server data after uploads complete.
@Observable @MainActor
final class UploadManager {
    // MARK: - Constants

    private static let maxRetries = 5
    private static let queueFileName = "pending_posts.json"
    private static let imageDirectoryName = "PendingUploads"

    // MARK: - Observable State

    /// The live upload queue. Bind to this for UI (e.g. profile grid).
    private(set) var pendingPosts: [PendingPost] = []

    /// Incremented each time an upload succeeds. Observe via `.onChange` to
    /// trigger a server-side refresh of the post list.
    private(set) var completedUploadCount: Int = 0

    // MARK: - Private

    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let logger = Logger(subsystem: "com.jazzrihal.pinstoria", category: "Upload")
    private var isProcessing = false
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid

    // MARK: - Directories

    private var baseDirectory: URL {
        let appSupport = fileManager.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!
        let dir = appSupport.appendingPathComponent("CameraApp", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        protectFile(at: dir)
        return dir
    }

    private var imageDirectory: URL {
        let dir = baseDirectory.appendingPathComponent(Self.imageDirectoryName, isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        protectFile(at: dir)
        return dir
    }

    private var queueFileURL: URL {
        baseDirectory.appendingPathComponent(Self.queueFileName)
    }

    // MARK: - Initialization

    init() {
        loadQueue()
    }

    // MARK: - Enqueue

    /// Compresses the image to JPEG, saves to disk, and adds to the upload queue.
    func enqueue(_ input: PostEnqueueInput) {
        let postId = UUID()
        let fileName = "\(postId.uuidString).jpg"

        guard let data = input.image.jpegData(compressionQuality: 0.8) else {
            logger.error("Failed to compress queued image.")
            return
        }

        saveImage(data, fileName: fileName)

        let post = PendingPost(
            id: postId,
            localImageFileName: fileName,
            caption: input.caption,
            latitude: input.latitude,
            longitude: input.longitude,
            locationName: input.locationName,
            scope: input.scope,
            createdAt: Date(),
            userId: input.userId,
            status: .queued
        )

        pendingPosts.insert(post, at: 0)
        persistQueue()

        Task { await processQueue() }
    }

    // MARK: - Save Draft

    /// Saves the image to disk and creates a draft post that will NOT be uploaded
    /// until the user explicitly promotes it.
    func saveDraft(_ input: PostEnqueueInput) {
        let postId = UUID()
        let fileName = "\(postId.uuidString).jpg"

        guard let data = input.image.jpegData(compressionQuality: 0.8) else {
            logger.error("Failed to compress draft image.")
            return
        }

        saveImage(data, fileName: fileName)

        let post = PendingPost(
            id: postId,
            localImageFileName: fileName,
            caption: input.caption,
            latitude: input.latitude,
            longitude: input.longitude,
            locationName: input.locationName,
            scope: input.scope,
            createdAt: Date(),
            userId: input.userId,
            status: .draft
        )

        pendingPosts.insert(post, at: 0)
        persistQueue()
    }

    // MARK: - Queue Processing

    /// Sequentially uploads each queued or retryable failed item.
    func processQueue() async {
        guard !isProcessing else { return }
        guard activeSessionUserId() != nil else { return }
        isProcessing = true
        defer { isProcessing = false }

        let postIds = pendingPosts.map(\.id)
        for postId in postIds {
            await processUpload(postId: postId)
        }
    }

    private func processUpload(postId: UUID) async {
        guard let index = pendingPosts.firstIndex(where: { $0.id == postId }) else { return }
        let post = pendingPosts[index]

        guard shouldAttemptUpload(post),
              Self.canProcessUpload(postUserId: post.userId, currentUserId: activeSessionUserId())
        else {
            return
        }

        pendingPosts[index].status = .uploading
        persistQueue()

        do {
            try await upload(post)
        } catch {
            markUploadFailed(post, error: error)
        }
    }

    private func shouldAttemptUpload(_ post: PendingPost) -> Bool {
        post.status == .queued || (post.status == .failed && post.retryCount < Self.maxRetries)
    }

    private func upload(_ post: PendingPost) async throws {
        guard let imageData = loadImage(fileName: post.localImageFileName) else {
            removePost(post)
            return
        }
        guard Self.canProcessUpload(postUserId: post.userId, currentUserId: activeSessionUserId()) else {
            resetPostToQueued(post.id)
            return
        }

        let storagePath = "\(post.userId)/\(post.id).jpg"
        try await SupabaseManager.client.storage
            .from("post-images")
            .upload(storagePath, data: imageData, options: .init(contentType: "image/jpeg"))

        guard Self.canProcessUpload(postUserId: post.userId, currentUserId: activeSessionUserId()) else {
            try? await SupabaseManager.client.storage
                .from("post-images")
                .remove(paths: [storagePath])
            resetPostToQueued(post.id)
            return
        }

        try await insertPost(post, storagePath: storagePath)
        deleteImage(fileName: post.localImageFileName)
        pendingPosts.removeAll { $0.id == post.id }
        persistQueue()
        completedUploadCount += 1
    }

    private func insertPost(_ post: PendingPost, storagePath: String) async throws {
        let insert = PublicSchema.PostsInsert(
            caption: post.caption,
            createdAt: nil,
            id: post.id,
            imagePath: storagePath,
            latitude: post.latitude,
            location: nil,
            locationName: post.locationName,
            longitude: post.longitude,
            scope: post.scope,
            userId: post.userId
        )
        try await SupabaseManager.client.from("posts").insert(insert).execute()
    }

    private func resetPostToQueued(_ postId: UUID) {
        guard let index = pendingPosts.firstIndex(where: { $0.id == postId }) else { return }
        pendingPosts[index].status = .queued
        persistQueue()
    }

    private func markUploadFailed(_ post: PendingPost, error: Error) {
        logger.error("Upload failed for post \(post.id.uuidString, privacy: .private): \(String(describing: error), privacy: .private)")
        guard let index = pendingPosts.firstIndex(where: { $0.id == post.id }) else { return }
        pendingPosts[index].status = .failed
        pendingPosts[index].retryCount += 1
        persistQueue()
    }

    /// Manually retry a specific failed post.
    func retryPost(_ post: PendingPost) {
        guard let idx = pendingPosts.firstIndex(where: { $0.id == post.id }) else { return }
        pendingPosts[idx].status = .queued
        persistQueue()
        Task { await processQueue() }
    }

    /// Remove a post from the queue (e.g. user dismisses a failed upload).
    func removePost(_ post: PendingPost) {
        deleteImage(fileName: post.localImageFileName)
        pendingPosts.removeAll { $0.id == post.id }
        persistQueue()
    }

    // MARK: - Background Support

    /// Call when the app enters background. Requests ~30s of execution time
    /// to finish any in-progress uploads.
    func handleBackground() {
        guard !pendingPosts.isEmpty else { return }
        guard activeSessionUserId() != nil else { return }
        backgroundTaskID = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }

        Task {
            await processQueue()
            endBackgroundTask()
        }
    }

    /// Removes pending posts that belong to a different user than the
    /// current session. These are orphaned leftovers from a previous login.
    func removeOrphanedPosts() {
        guard let currentUserId = SupabaseManager.client.auth.currentSession?.user.id
        else { return }
        let orphaned = pendingPosts.filter { $0.userId != currentUserId }
        for post in orphaned {
            deleteImage(fileName: post.localImageFileName)
        }
        if !orphaned.isEmpty {
            pendingPosts.removeAll { $0.userId != currentUserId }
            persistQueue()
        }
    }

    /// Call when the app enters foreground. Cleans orphaned posts, retries
    /// failed items, then processes the queue.
    func handleForeground() {
        guard activeSessionUserId() != nil else { return }
        for index in pendingPosts.indices where pendingPosts[index].status == .failed {
            if pendingPosts[index].retryCount < Self.maxRetries {
                pendingPosts[index].status = .queued
            }
        }
        persistQueue()
        Task { await processQueue() }
    }

    private func endBackgroundTask() {
        guard backgroundTaskID != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        backgroundTaskID = .invalid
    }

    func resetSessionState() {
        endBackgroundTask()
        for post in pendingPosts {
            deleteImage(fileName: post.localImageFileName)
        }
        pendingPosts = []
        try? fileManager.removeItem(at: queueFileURL)
        isProcessing = false
    }

    nonisolated static func canProcessUpload(postUserId: UUID, currentUserId: UUID?) -> Bool {
        postUserId == currentUserId
    }

    // MARK: - Persistence (JSON)

    private func persistQueue() {
        do {
            let data = try encoder.encode(pendingPosts)
            try data.write(to: queueFileURL, options: protectedWriteOptions)
            protectFile(at: queueFileURL)
        } catch {
            logger.error("Failed to persist upload queue: \(String(describing: error), privacy: .private)")
        }
    }

    private func loadQueue() {
        guard let data = try? Data(contentsOf: queueFileURL),
              let posts = try? decoder.decode([PendingPost].self, from: data)
        else { return }

        pendingPosts = posts
        for index in pendingPosts.indices where pendingPosts[index].status == .uploading {
            pendingPosts[index].status = .queued
        }
        persistQueue()
    }

    // MARK: - Persistence (Images)

    private func saveImage(_ data: Data, fileName: String) {
        let url = imageDirectory.appendingPathComponent(fileName)
        try? data.write(to: url, options: protectedWriteOptions)
        protectFile(at: url)
    }

    func loadImage(fileName: String) -> Data? {
        let url = imageDirectory.appendingPathComponent(fileName)
        return try? Data(contentsOf: url)
    }

    private func deleteImage(fileName: String) {
        let url = imageDirectory.appendingPathComponent(fileName)
        try? fileManager.removeItem(at: url)
    }

    private var protectedWriteOptions: Data.WritingOptions {
        [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
    }

    private func activeSessionUserId() -> UUID? {
        SupabaseManager.client.auth.currentSession?.user.id
    }

    private func protectFile(at url: URL) {
        var protectedURL = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? protectedURL.setResourceValues(values)
    }
}
