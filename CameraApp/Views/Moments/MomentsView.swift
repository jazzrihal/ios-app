import Nuke
import SwiftUI

struct MomentsView: View {
    @Environment(MomentsStore.self) private var store
    @State private var prefetcher = ImagePrefetcher()

    var body: some View {
        NavigationStack {
            List {
                if store.moments.isEmpty, !store.isLoading {
                    EmptyStateView(
                        icon: "clock.badge.questionmark",
                        title: "No Moments Yet",
                        subtitle: "Save moments from the Explore tab to see them here."
                    )
                    .frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(sortedMoments) { moment in
                        let posts = store.nearbyPosts[moment.id] ?? []
                        MomentCard(
                            moment: moment,
                            posts: posts
                        ) {
                            navigateToExplore(moment)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task { await store.deleteMoment(moment) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(
                            top: AppStyle.Spacing.small,
                            leading: AppStyle.Padding.screenHorizontal,
                            bottom: AppStyle.Spacing.small,
                            trailing: AppStyle.Padding.screenHorizontal
                        ))
                        .listRowBackground(Color.clear)
                    }
                }
            }
            .listStyle(.plain)
            .tabLoadable(
                isLoading: store.isLoading,
                isRefreshing: store.isRefreshing,
                onRefresh: { await store.refreshMoments() }
            )
            .navigationTitle("Moments")
            .navigationBarTitleDisplayMode(.large)
            .onChange(of: store.nearbyPosts.keys.sorted()) { _, _ in
                let urls = store.nearbyPosts.values.flatMap { $0.map(\.imageURL) }
                prefetcher.startPrefetching(with: urls)
            }
        }
    }

    // MARK: - Helpers

    private var sortedMoments: [Moment] {
        store.moments.sorted { $0.addedAt > $1.addedAt }
    }

    private func navigateToExplore(_ moment: Moment) {
        store.pendingMoment = moment
        store.selectedTab = 0
    }
}

// MARK: - Preview

#Preview {
    MomentsView()
        .environment(MomentsStore())
}
