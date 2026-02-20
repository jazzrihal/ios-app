import Foundation
import Observation
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
    private var isProcessing = false
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid

    // MARK: - Directories

    private var baseDirectory: URL {
        let appSupport = fileManager.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!
        let dir = appSupport.appendingPathComponent("CameraApp", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private var imageDirectory: URL {
        let dir = baseDirectory.appendingPathComponent(Self.imageDirectoryName, isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
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
            print("[UploadManager] Failed to compress image.")
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
            print("[UploadManager] Failed to compress image for draft.")
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
        isProcessing = true
        defer { isProcessing = false }

        let currentUserId = SupabaseManager.client.auth.currentSession?.user.id
        let postIds = pendingPosts.map(\.id)

        for postId in postIds {
            guard let index = pendingPosts.firstIndex(where: { $0.id == postId }) else { continue }
            let post = pendingPosts[index]

            guard post.status == .queued
                || (post.status == .failed && post.retryCount < Self.maxRetries)
            else {
                continue
            }

            if let currentUserId, post.userId != currentUserId {
                continue
            }

            pendingPosts[index].status = .uploading
            persistQueue()

            do {
                let imageData = loadImage(fileName: post.localImageFileName)
                guard let imageData else {
                    removePost(post)
                    continue
                }

                let storagePath = "\(post.userId)/\(post.id).jpg"
                try await SupabaseManager.client.storage
                    .from("post-images")
                    .upload(storagePath, data: imageData, options: .init(contentType: "image/jpeg"))

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

                deleteImage(fileName: post.localImageFileName)
                pendingPosts.removeAll { $0.id == post.id }
                persistQueue()
                completedUploadCount += 1
            } catch {
                print("[UploadManager] Upload failed for \(post.id): \(error)")
                if let idx = pendingPosts.firstIndex(where: { $0.id == post.id }) {
                    pendingPosts[idx].status = .failed
                    pendingPosts[idx].retryCount += 1
                    persistQueue()
                }
            }
        }
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
        backgroundTaskID = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }

        Task {
            await processQueue()
            endBackgroundTask()
        }
    }

    /// Call when the app enters foreground. Retries failed items.
    func handleForeground() {
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

    // MARK: - Persistence (JSON)

    private func persistQueue() {
        do {
            let data = try encoder.encode(pendingPosts)
            try data.write(to: queueFileURL, options: .atomic)
        } catch {
            print("[UploadManager] Failed to persist queue: \(error)")
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
        try? data.write(to: url, options: .atomic)
    }

    func loadImage(fileName: String) -> Data? {
        let url = imageDirectory.appendingPathComponent(fileName)
        return try? Data(contentsOf: url)
    }

    private func deleteImage(fileName: String) {
        let url = imageDirectory.appendingPathComponent(fileName)
        try? fileManager.removeItem(at: url)
    }
}
