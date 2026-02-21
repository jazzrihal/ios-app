#if DEBUG
    import SwiftData
    import SwiftUI

    @MainActor
    enum PreviewContainer {
        static let shared: ModelContainer = {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            return (try? ModelContainer(
                for: CacheEntry.self, CachedPost.self, CachedUser.self, CachedMoment.self,
                configurations: config
            )) ?? (try! ModelContainer(for: CacheEntry.self, configurations: config)) // swiftlint:disable:this force_try
        }()

        static var postRepository: DefaultPostRepository {
            DefaultPostRepository(modelContext: ModelContext(shared))
        }

        static var friendRepository: DefaultFriendRepository {
            DefaultFriendRepository(modelContext: ModelContext(shared))
        }

        static var momentRepository: DefaultMomentRepository {
            DefaultMomentRepository(modelContext: ModelContext(shared))
        }

        static var profileRepository: DefaultProfileRepository {
            DefaultProfileRepository(modelContext: ModelContext(shared))
        }
    }
#endif
