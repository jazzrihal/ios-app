import Foundation
import UIKit

// MARK: - Pending Post

/// A post that has been captured but not yet uploaded.
/// Persisted as JSON alongside the JPEG image in the app's Library/PendingUploads directory.
struct PendingPost: Identifiable, Codable {
    let id: UUID
    let localImageFileName: String
    let caption: String?
    let latitude: Double
    let longitude: Double
    let locationName: String?
    let scope: String
    let createdAt: Date
    let userId: UUID
    var status: UploadStatus
    var retryCount: Int = 0

    enum UploadStatus: String, Codable {
        case queued, uploading, failed
    }
}

// MARK: - Enqueue Input

/// Input for creating a new pending post in the upload queue.
struct PostEnqueueInput: Sendable {
    let image: UIImage
    let caption: String?
    let latitude: Double
    let longitude: Double
    let locationName: String?
    let scope: String
    let userId: UUID
}
