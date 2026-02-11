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

            Color.clear
                .tabItem {
                    Label("Camera", systemImage: "camera.fill")
                }
                .tag(1)
                .accessibilityIdentifier("CameraTab")
                .onAppear {
                    showCamera = true
                }

            MomentsView()
                .tabItem {
                    Label("Moments", systemImage: "clock.arrow.circlepath")
                }
                .tag(2)
                .accessibilityIdentifier("MomentsTab")

            FriendsView()
                .tabItem {
                    Label("Friends", systemImage: "person.2.fill")
                }
                .tag(3)
                .accessibilityIdentifier("FriendsTab")
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
