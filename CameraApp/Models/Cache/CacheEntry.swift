import Foundation
import SwiftData

@Model
final class CacheEntry {
    @Attribute(.unique) var key: String
    var fetchedAt: Date

    init(key: String, fetchedAt: Date = Date()) {
        self.key = key
        self.fetchedAt = fetchedAt
    }

    func isFresh(ttl: TimeInterval) -> Bool {
        Date().timeIntervalSince(fetchedAt) < ttl
    }
}
