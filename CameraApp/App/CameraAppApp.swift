import SwiftUI

@main
struct CameraAppApp: App {
    @State private var momentsStore = MomentsStore()
    @State private var friendsStore = FriendsStore()
    @State private var showCamera = false
    @State private var previousTab: Int = 0

    var body: some Scene {
        WindowGroup {
            @Bindable var store = momentsStore
            TabView(
                selection: Binding(
                    get: { store.selectedTab },
                    set: { newValue in
                        if newValue == 1 {
                            // Save current tab so we can return to it
                            previousTab = store.selectedTab
                            store.selectedTab = newValue
                            showCamera = true
                        } else {
                            store.selectedTab = newValue
                        }
                    }
                )
            ) {
                ExploreView()
                    .tabItem {
                        Label("Explore", systemImage: "magnifyingglass")
                    }
                    .tag(0)

                Color.clear
                    .tabItem {
                        Label("Camera", systemImage: "camera.fill")
                    }
                    .tag(1)

                MomentsView()
                    .tabItem {
                        Label("Moments", systemImage: "clock.arrow.circlepath")
                    }
                    .tag(2)

                FriendsView()
                    .tabItem {
                        Label("Friends", systemImage: "person.2.fill")
                    }
                    .tag(3)
            }
            .fullScreenCover(isPresented: $showCamera, onDismiss: {
                // Return to whichever tab was active before camera
                store.selectedTab = previousTab
            }) {
                CameraFlowView()
            }
            .environment(momentsStore)
            .environment(friendsStore)
        }
    }
}
