@testable import CameraApp
import Testing

@Suite("PostRepository Mutations")
struct PostRepositoryMutationTests {
    @Test("normalizedCaption trims and nils empty values")
    func normalizedCaption() {
        #expect(DefaultPostRepository.normalizedCaption(nil) == nil)
        #expect(DefaultPostRepository.normalizedCaption("") == nil)
        #expect(DefaultPostRepository.normalizedCaption("   ") == nil)
        #expect(DefaultPostRepository.normalizedCaption("  hello world  ") == "hello world")
    }

    @Test("makePostUpdate stores typed scope and normalized caption")
    func makePostUpdate() {
        let updates = DefaultPostRepository.makePostUpdate(caption: "  hello  ", scope: .friends)
        #expect(updates.caption == "hello")
        #expect(updates.scope == "friends")
        #expect(updates.imagePath == nil)
        #expect(updates.latitude == nil)
        #expect(updates.longitude == nil)
    }
}
