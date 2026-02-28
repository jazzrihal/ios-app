import NukeUI
import SwiftUI

// MARK: - Friends Tab Sections

enum FriendsSection: String, CaseIterable {
    case feed = "Feed"
    case friends = "Friends"
    case addFriend = "Add Friend"
}

// MARK: - Friends View

struct FriendsView: View {
    @Environment(FriendsStore.self) private var store
    @Environment(DefaultPostRepository.self) private var postRepository
    @State private var selectedSection: FriendsSection = .feed
    @State private var searchText = ""
    @State private var searchTask: Task<Void, Never>?
    @State private var feedViewModel = FriendsFeedViewModel()
    @State private var feedNavigateToIndex: Int?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                sectionPicker

                switch selectedSection {
                case .friends:
                    friendsListSection
                case .feed:
                    friendsFeedSection
                case .addFriend:
                    addFriendSection
                }
            }
            .navigationTitle("Friends")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(isPresented: Binding(
                get: { feedNavigateToIndex != nil },
                set: { if !$0 { feedNavigateToIndex = nil } }
            )) {
                if let index = feedNavigateToIndex {
                    PostDetailView(posts: feedViewModel.posts, initialIndex: index, queryDate: Date())
                }
            }
        }
    }

    // MARK: - Section Picker

    private var sectionPicker: some View {
        HStack(spacing: 0) {
            ForEach(FriendsSection.allCases, id: \.self) { section in
                Button {
                    withAnimation(AppStyle.Animation.transition) {
                        selectedSection = section
                        searchText = ""
                        searchTask?.cancel()
                        store.clearSearchResults()
                    }
                } label: {
                    VStack(spacing: AppStyle.Spacing.compact) {
                        HStack(spacing: AppStyle.Spacing.tight) {
                            Text(section.rawValue)
                                .font(.subheadline.weight(.semibold))

                            if section == .friends, !store.incomingRequests.isEmpty {
                                badgeView(count: store.incomingRequests.count)
                            }
                        }

                        Rectangle()
                            .fill(selectedSection == section ? Color.primary : Color.clear)
                            .frame(height: 2)
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(selectedSection == section ? .primary : .secondary)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("\(section.rawValue)SectionButton")
            }
        }
        .padding(.horizontal, AppStyle.Padding.screenHorizontal)
        .padding(.top, AppStyle.Spacing.tight)
    }

    private func badgeView(count: Int) -> some View {
        Text("\(count)")
            .font(.caption2.weight(.bold))
            .foregroundStyle(Color(.systemBackground))
            .padding(.horizontal, AppStyle.Spacing.compact)
            .padding(.vertical, 2)
            .background(Color.primary, in: RoundedRectangle(cornerRadius: AppStyle.CornerRadius.badge))
    }

    // MARK: - Friends List Section

    private var friendsListSection: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                AppSearchBar(text: $searchText, placeholder: "Search friends…")
                    .padding(.horizontal, AppStyle.Padding.screenHorizontal)
                    .padding(.top, AppStyle.Spacing.medium)

                if !store.incomingRequests.isEmpty, searchText.isEmpty {
                    incomingRequestsSection
                }

                let filtered = store.searchFriends(query: searchText)
                if filtered.isEmpty {
                    EmptyStateView(
                        icon: searchText.isEmpty ? "person.2" : "magnifyingglass",
                        title: searchText.isEmpty ? "No Friends Yet" : "No Results",
                        subtitle: searchText.isEmpty
                            ? "Use the Add Friend tab to find people"
                            : "No friends match \"\(searchText)\""
                    )
                } else {
                    ForEach(filtered) { user in
                        NavigationLink(destination: FriendProfileView(user: user)) {
                            FriendRow(user: user)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("FriendRow")
                    }
                    .padding(.horizontal, AppStyle.Padding.screenHorizontal)
                }
            }
            .padding(.bottom, AppStyle.Spacing.large)
        }
        .refreshable {
            await refreshFriendsSection()
        }
    }

    private var incomingRequestsSection: some View {
        VStack(alignment: .leading, spacing: AppStyle.Spacing.small) {
            HStack {
                Image(systemName: "person.badge.plus")
                    .foregroundStyle(.primary)
                Text("Friend Requests")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(store.incomingRequests.count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color(.systemBackground))
                    .padding(.horizontal, AppStyle.Spacing.small)
                    .padding(.vertical, 3)
                    .background(Color.primary, in: RoundedRectangle(cornerRadius: AppStyle.CornerRadius.badge))
            }
            .padding(.horizontal, AppStyle.Padding.screenHorizontal)
            .padding(.top, AppStyle.Padding.screenHorizontal)

            ForEach(store.incomingRequests) { user in
                IncomingRequestRow(user: user)
            }
            .padding(.horizontal, AppStyle.Padding.screenHorizontal)

            Divider()
                .padding(.horizontal, AppStyle.Padding.screenHorizontal)
                .padding(.top, AppStyle.Spacing.tight)
        }
    }

    // MARK: - Friends Feed Section

    private var friendsFeedSection: some View {
        ScrollView {
            if feedViewModel.isLoading, feedViewModel.posts.isEmpty {
                ProgressView()
                    .padding(.top, AppStyle.Padding.emptyStateTop)
            } else if feedViewModel.posts.isEmpty {
                EmptyStateView(
                    icon: "photo.on.rectangle",
                    title: "No Posts Yet",
                    subtitle: "When your friends share photos, they'll show up here"
                )
            } else {
                PhotoGrid(
                    items: feedViewModel.posts,
                    columns: 2,
                    hasMorePages: feedViewModel.hasMorePages,
                    isLoadingMore: feedViewModel.isLoadingMore,
                    onLoadMore: { Task { await feedViewModel.loadNextPage(friends: store.friends) } },
                    cell: { index, post in
                        Button {
                            feedNavigateToIndex = index
                        } label: {
                            RemoteImage(url: post.imageURL)
                                .aspectRatio(1, contentMode: .fill)
                                .clipped()
                        }
                        .buttonStyle(.plain)
                    }
                )
            }
        }
        .refreshable {
            await feedViewModel.refreshPosts(friends: store.friends)
        }
        .task(id: store.friends.map(\.id)) {
            feedViewModel.postRepository = postRepository
            await feedViewModel.loadPosts(friends: store.friends)
        }
    }

    // MARK: - Add Friend Section

    private var addFriendSection: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                AppSearchBar(text: $searchText, placeholder: "Search by username or name…")
                    .padding(.horizontal, AppStyle.Padding.screenHorizontal)
                    .padding(.top, AppStyle.Spacing.medium)

                if searchText.isEmpty {
                    EmptyStateView(
                        icon: "person.badge.plus",
                        title: "Add a Friend",
                        subtitle: "Search by username or display name\nto find and add friends"
                    )
                } else if searchText.count < 2 {
                    EmptyStateView(
                        icon: "magnifyingglass",
                        title: "Keep Typing…",
                        subtitle: "Enter at least 2 characters to search"
                    )
                } else if store.isSearching {
                    ProgressView()
                        .padding(.top, AppStyle.Padding.emptyStateTop)
                } else if store.searchResults.isEmpty {
                    EmptyStateView(
                        icon: "magnifyingglass",
                        title: "No People Found",
                        subtitle: "Try a different username or name"
                    )
                } else {
                    ForEach(store.searchResults) { user in
                        NavigationLink(destination: FriendProfileView(user: user)) {
                            DiscoverUserRow(user: user)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("DiscoverUserRow")
                    }
                    .padding(.horizontal, AppStyle.Padding.screenHorizontal)
                }
            }
            .padding(.bottom, AppStyle.Spacing.large)
        }
        .refreshable {
            await refreshAddFriendSection()
        }
        .onChange(of: searchText) { _, newValue in
            guard selectedSection == .addFriend else { return }

            searchTask?.cancel()

            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.count >= 2 else {
                store.clearSearchResults()
                return
            }

            searchTask = Task {
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled else { return }
                await store.remoteSearchUsers(query: newValue)
            }
        }
    }

    @MainActor
    private func refreshFriendsSection() async {
        await store.refreshAll()
    }

    @MainActor
    private func refreshAddFriendSection() async {
        searchTask?.cancel()
        await store.refreshAll()

        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return }
        await store.remoteSearchUsers(query: trimmed)
    }
}

// MARK: - Friend Row

struct FriendRow: View {
    let user: User

    var body: some View {
        HStack(spacing: AppStyle.Padding.cardInner) {
            AvatarView(user: user, size: AppStyle.IconSize.avatarMedium)

            VStack(alignment: .leading, spacing: AppStyle.Spacing.tight) {
                Text(user.displayName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                Text("@\(user.username)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .cardRow()
        .padding(.top, AppStyle.Spacing.small)
    }
}

// MARK: - Incoming Request Row

struct IncomingRequestRow: View {
    let user: User
    @Environment(FriendsStore.self) private var store

    var body: some View {
        HStack(spacing: AppStyle.Spacing.medium) {
            NavigationLink(destination: FriendProfileView(user: user)) {
                AvatarView(user: user, size: AppStyle.IconSize.tapTarget)
            }

            VStack(alignment: .leading, spacing: AppStyle.Spacing.grid) {
                NavigationLink(destination: FriendProfileView(user: user)) {
                    Text(user.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }

                Text("\(user.mutualFriendCount) mutual friends")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                withAnimation(AppStyle.Animation.spring) {
                    store.acceptRequest(from: user)
                }
            } label: {
                Text("Accept")
            }
            .buttonStyle(.appPill)

            Button {
                withAnimation(AppStyle.Animation.spring) {
                    store.declineRequest(from: user)
                }
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.appIcon)
        }
        .cardRow()
        .padding(.top, AppStyle.Spacing.tight)
    }
}

// MARK: - Discover User Row

struct DiscoverUserRow: View {
    let user: User
    @Environment(FriendsStore.self) private var store

    var body: some View {
        HStack(spacing: AppStyle.Padding.cardInner) {
            AvatarView(user: user, size: AppStyle.IconSize.avatarMedium)

            VStack(alignment: .leading, spacing: AppStyle.Spacing.tight) {
                Text(user.displayName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                HStack(spacing: AppStyle.Spacing.tight) {
                    Text("@\(user.username)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if user.mutualFriendCount > 0 {
                        Text("·")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Text("\(user.mutualFriendCount) mutual")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            statusButton
        }
        .cardRow()
        .padding(.top, AppStyle.Spacing.small)
    }

    @ViewBuilder private var statusButton: some View {
        let friendStatus = store.status(for: user)

        switch friendStatus {
        case .none:
            Button {
                withAnimation(AppStyle.Animation.spring) {
                    store.sendRequest(to: user)
                }
            } label: {
                HStack(spacing: AppStyle.Spacing.tight) {
                    Image(systemName: "person.badge.plus")
                        .font(.caption2)
                    Text("Add")
                }
            }
            .buttonStyle(.appPill)

        case .pendingSent:
            Button {
                withAnimation(AppStyle.Animation.spring) {
                    store.cancelRequest(to: user)
                }
            } label: {
                HStack(spacing: AppStyle.Spacing.tight) {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text("Pending")
                }
            }
            .buttonStyle(.appPillSecondary)

        case .pendingReceived:
            Button {
                withAnimation(AppStyle.Animation.spring) {
                    store.acceptRequest(from: user)
                }
            } label: {
                HStack(spacing: AppStyle.Spacing.tight) {
                    Image(systemName: "checkmark")
                        .font(.caption2)
                    Text("Accept")
                }
            }
            .buttonStyle(.appPill)

        case .friends:
            HStack(spacing: AppStyle.Spacing.tight) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption2)
                Text("Friends")
                    .font(.caption.weight(.semibold))
            }
            .padding(.horizontal, AppStyle.Padding.pillHorizontal)
            .padding(.vertical, AppStyle.Padding.pillVertical)
            .foregroundStyle(.primary)
        }
    }
}

// MARK: - Preview

#Preview {
    FriendsView()
        .environment(FriendsStore())
        .environment(PostMutationStore())
        .environment(PreviewContainer.postRepository)
}
