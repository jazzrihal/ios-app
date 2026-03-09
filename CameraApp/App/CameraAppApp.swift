import SwiftData
import SwiftUI

@main
struct CameraAppApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var authManager = AuthManager()
    @State private var momentsStore = MomentsStore()
    @State private var friendsStore = FriendsStore()
    @State private var uploadManager = UploadManager()
    @State private var postMutationStore = PostMutationStore()
    @State private var networkMonitor = NetworkMonitor()
    @State private var cacheInvalidator = CacheInvalidator()
    @State private var friendRealtimeService = FriendRealtimeService()
    @State private var friendsBootstrapTask: Task<Void, Never>?
    @State private var showCamera = false
    @State private var previousTab: Int = 0

    private let modelContainer: ModelContainer
    @State private var postRepository: DefaultPostRepository
    @State private var friendRepository: DefaultFriendRepository
    @State private var momentRepository: DefaultMomentRepository
    @State private var profileRepository: DefaultProfileRepository
    @State private var notificationRepository = DefaultNotificationRepository()

    init() {
        do {
            let container = try ModelContainer(
                for: CacheEntry.self, CachedPost.self, CachedUser.self, CachedMoment.self
            )
            modelContainer = container
            let context = ModelContext(container)
            _postRepository = State(initialValue: DefaultPostRepository(modelContext: context))
            _friendRepository = State(initialValue: DefaultFriendRepository(modelContext: context))
            _momentRepository = State(initialValue: DefaultMomentRepository(modelContext: context))
            _profileRepository = State(initialValue: DefaultProfileRepository(modelContext: context))
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isInitializing {
                    ProgressView()
                } else if authManager.isAuthenticated {
                    mainTabView
                } else {
                    AuthView()
                }
            }
            .environment(authManager)
            .environment(momentsStore)
            .environment(friendsStore)
            .environment(uploadManager)
            .environment(postMutationStore)
            .environment(networkMonitor)
            .environment(postRepository)
            .environment(friendRepository)
            .environment(momentRepository)
            .environment(profileRepository)
            .environment(cacheInvalidator)
            .environment(notificationRepository)
            .onChange(of: authManager.isAuthenticated, initial: true) {
                if authManager.isAuthenticated, let uid = authManager.userId {
                    friendsBootstrapTask?.cancel()

                    friendsStore.currentUserId = uid
                    momentsStore.currentUserId = uid
                    postMutationStore.currentUserId = uid
                    uploadManager.removeOrphanedPosts()

                    cacheInvalidator.configure(
                        posts: postRepository,
                        friends: friendRepository,
                        moments: momentRepository,
                        profiles: profileRepository
                    )

                    friendsStore.repository = friendRepository
                    friendsStore.cacheInvalidator = cacheInvalidator
                    momentsStore.repository = momentRepository
                    momentsStore.cacheInvalidator = cacheInvalidator
                    postMutationStore.cacheInvalidator = cacheInvalidator

                    friendsBootstrapTask = Task {
                        await friendsStore.loadAll()
                        guard !Task.isCancelled else { return }
                        guard authManager.isAuthenticated else { return }
                        guard let currentUserId = authManager.userId, currentUserId == uid else {
                            return
                        }

                        await friendRealtimeService.start(userId: uid) {
                            await friendsStore.refreshAll()
                        }
                    }
                    Task { await momentsStore.loadMoments() }
                } else {
                    friendsBootstrapTask?.cancel()
                    friendsBootstrapTask = nil
                    Task { await friendRealtimeService.stop() }
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .active:
                    uploadManager.handleForeground()
                case .background:
                    uploadManager.handleBackground()
                default:
                    break
                }
            }
        }
    }

    // MARK: - Main Tab View

    @ViewBuilder private var mainTabView: some View {
        @Bindable var store = momentsStore
        TabView(selection: $store.selectedTab) {
            ExploreView()
                .tabItem {
                    Label("Explore", systemImage: "magnifyingglass")
                }
                .tag(0)
                .accessibilityIdentifier("ExploreTab")

            MomentsView()
                .tabItem {
                    Label("Moments", systemImage: "clock.arrow.circlepath")
                }
                .tag(2)
                .accessibilityIdentifier("MomentsTab")

            Color.clear
                .tabItem {
                    Label("Camera", systemImage: "camera.fill")
                }
                .tag(1)
                .accessibilityIdentifier("CameraTab")
                .onAppear {
                    showCamera = true
                }

            FriendsView()
                .tabItem {
                    Label("Friends", systemImage: "person.2.fill")
                }
                .tag(3)
                .accessibilityIdentifier("FriendsTab")

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle")
                }
                .tag(4)
                .accessibilityIdentifier("ProfileTab")
        }
        .onChange(of: store.selectedTab) { oldValue, newValue in
            if newValue == 1 {
                previousTab = oldValue
            }
        }
        .fullScreenCover(
            isPresented: $showCamera,
            onDismiss: {
                store.selectedTab = previousTab
            },
            content: {
                CameraFlowView()
            }
        )
    }
}
