import SwiftUI

struct FriendProfileView: View {
    @Environment(FriendsStore.self) private var store
    @Environment(PostMutationStore.self) private var postMutationStore
    @Environment(DefaultPostRepository.self) private var postRepository
    @Environment(DefaultProfileRepository.self) private var profileRepository
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: FriendProfileViewModel

    init(user: User) {
        _viewModel = State(initialValue: FriendProfileViewModel(user: user))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ProfileHeaderView(user: viewModel.user) {
                    HStack(spacing: AppStyle.Padding.screenHorizontal) {
                        ProfileStatItem(value: viewModel.ownPostCount, label: "Posts")
                        ProfileStatItem(value: viewModel.user.friendCount, label: "Friends")
                        ProfileStatItem(value: viewModel.user.mutualFriendCount, label: "Mutual")
                    }
                }
                .padding(.horizontal, AppStyle.Padding.screenHorizontal)
                .padding(.top, AppStyle.Spacing.medium)

                if !viewModel.user.bio.isEmpty {
                    ProfileBioView(bio: viewModel.user.bio)
                        .padding(.horizontal, AppStyle.Padding.screenHorizontal)
                        .padding(.top, AppStyle.Spacing.row)
                }

                actionButtons
                    .padding(.horizontal, AppStyle.Padding.screenHorizontal)
                    .padding(.top, AppStyle.Spacing.medium)

                ProfilePostsSection(
                    isLoading: viewModel.isLoadingPosts,
                    items: viewModel.userPosts.map { .uploaded($0) },
                    uploadedPosts: viewModel.userPosts,
                    hasMorePages: viewModel.hasMorePages,
                    isLoadingMore: viewModel.isLoadingMore,
                    onLoadMore: { Task { await viewModel.loadMorePosts() } },
                    emptyContent: {
                        friendPostsEmptyState
                    }
                )
                .padding(.top, AppStyle.Padding.screenHorizontal)
            }
        }
        .refreshable {
            await viewModel.refreshPosts()
            postMutationStore.seedFromPosts(viewModel.userPosts)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if store.status(for: viewModel.user) == .friends {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(role: .destructive) {
                            viewModel.showRemoveConfirmation = true
                        } label: {
                            Label("Remove Friend", systemImage: "person.badge.minus")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .onAppear {
            viewModel.postRepository = postRepository
            viewModel.profileRepository = profileRepository
            viewModel.loadFullProfile()
            Task {
                await viewModel.loadPosts()
                postMutationStore.seedFromPosts(viewModel.userPosts)
            }
        }
        .onChange(of: store.status(for: viewModel.user)) { _, _ in
            Task {
                await viewModel.loadPosts()
                postMutationStore.seedFromPosts(viewModel.userPosts)
            }
        }
        .onChange(of: viewModel.shouldDismiss) { _, shouldDismiss in
            if shouldDismiss { dismiss() }
        }
        .alert("Remove Friend", isPresented: $viewModel.showRemoveConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                viewModel.removeFriend(store: store)
            }
        } message: {
            Text("Are you sure you want to remove \(viewModel.user.displayName) from your friends? This cannot be undone.")
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        Group {
            let friendStatus = store.status(for: viewModel.user)

            switch friendStatus {
            case .none:
                Button {
                    viewModel.sendRequest(store: store)
                } label: {
                    HStack(spacing: AppStyle.Spacing.compact) {
                        Image(systemName: "person.badge.plus")
                        Text("Add Friend")
                    }
                }
                .buttonStyle(.appPrimary)

            case .pendingSent:
                Button {
                    viewModel.cancelRequest(store: store)
                } label: {
                    HStack(spacing: AppStyle.Spacing.compact) {
                        Image(systemName: "clock")
                        Text("Request Pending")
                    }
                }
                .buttonStyle(.appSecondary)

            case .pendingReceived:
                HStack(spacing: AppStyle.Spacing.row) {
                    Button {
                        viewModel.acceptRequest(store: store)
                    } label: {
                        HStack(spacing: AppStyle.Spacing.compact) {
                            Image(systemName: "checkmark")
                            Text("Accept")
                        }
                    }
                    .buttonStyle(.appPrimary)

                    Button {
                        viewModel.declineRequest(store: store)
                    } label: {
                        HStack(spacing: AppStyle.Spacing.compact) {
                            Image(systemName: "xmark")
                            Text("Decline")
                        }
                    }
                    .buttonStyle(.appSecondary)
                }

            case .friends:
                HStack(spacing: AppStyle.Spacing.compact) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.subheadline)
                    Text("Friends")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppStyle.Padding.buttonVertical)
                .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: AppStyle.CornerRadius.control))
            }
        }
    }

    // MARK: - Empty State

    private var friendPostsEmptyState: some View {
        Group {
            if store.status(for: viewModel.user) == .friends {
                EmptyStateView(
                    icon: "photo.on.rectangle.angled",
                    title: "No posts yet",
                    style: .compact
                )
            } else {
                EmptyStateView(
                    icon: "photo.on.rectangle.angled",
                    title: "No public posts",
                    subtitle: "Add \(viewModel.user.displayName) as a friend to see more.",
                    style: .compact
                )
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        FriendProfileView(user: User.sampleFriends().first!)
    }
    .environment(FriendsStore())
    .environment(MomentsStore())
    .environment(PostMutationStore())
    .environment(AuthManager())
    .environment(PreviewContainer.postRepository)
    .environment(PreviewContainer.profileRepository)
}
