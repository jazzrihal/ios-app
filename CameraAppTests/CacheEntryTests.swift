import Foundation
@testable import Pinstoria
import SwiftData
import Testing

@Suite("CacheEntry freshness")
struct CacheEntryTests {
    @Test("Fresh entry within TTL returns true")
    func freshEntry() {
        let entry = CacheEntry(key: "test", fetchedAt: Date())
        #expect(entry.isFresh(ttl: 60))
    }

    @Test("Stale entry past TTL returns false")
    func staleEntry() {
        let entry = CacheEntry(key: "test", fetchedAt: Date().addingTimeInterval(-120))
        #expect(!entry.isFresh(ttl: 60))
    }

    @Test("Entry exactly at TTL boundary is stale")
    func boundaryEntry() {
        let entry = CacheEntry(key: "test", fetchedAt: Date().addingTimeInterval(-60))
        #expect(!entry.isFresh(ttl: 60))
    }

    @Test("Zero TTL makes everything stale")
    func zeroTTL() {
        let entry = CacheEntry(key: "test", fetchedAt: Date())
        #expect(!entry.isFresh(ttl: 0))
    }

    @Test("Very old entry is stale")
    func veryOldEntry() {
        let entry = CacheEntry(key: "test", fetchedAt: Date().addingTimeInterval(-86400))
        #expect(!entry.isFresh(ttl: 300))
    }
}
