import SwiftUI

@main
struct CameraAppApp: App {
    @State private var momentsStore = MomentsStore()

    var body: some Scene {
        WindowGroup {
            @Bindable var store = momentsStore
            TabView(selection: $store.selectedTab) {
                ContentView()
                    .tabItem {
                        Label("Camera", systemImage: "camera.fill")
                    }
                    .tag(0)

                ExploreView()
                    .tabItem {
                        Label("Explore", systemImage: "magnifyingglass")
                    }
                    .tag(1)

                MomentsView()
                    .tabItem {
                        Label("Moments", systemImage: "clock.arrow.circlepath")
                    }
                    .tag(2)
            }
            .environment(momentsStore)
        }
    }
}
