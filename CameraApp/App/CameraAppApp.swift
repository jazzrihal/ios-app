import SwiftUI

@main
struct CameraAppApp: App {
    @State private var authManager = AuthManager()
    @State private var momentsStore = MomentsStore()
    @State private var friendsStore = FriendsStore()
    @State private var showCamera = false
    @State private var previousTab: Int = 0

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
            .onChange(of: authManager.isAuthenticated) {
                if authManager.isAuthenticated, let uid = authManager.userId {
                    friendsStore.currentUserId = uid
                    momentsStore.currentUserId = uid
                    Task { await friendsStore.loadAll() }
                    Task { await momentsStore.loadMoments() }
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
