import SwiftUI

struct FriendProfileView: View {
    @Environment(FriendsStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: FriendProfileViewModel

    init(user: User) {
        _viewModel = State(initialValue: FriendProfileViewModel(user: user))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ProfileHeaderView(user: viewModel.user) {
                    HStack(spacing: 16) {
                        ProfileStatItem(value: viewModel.userPosts.count, label: "Posts")
                        ProfileStatItem(value: viewModel.user.friendCount, label: "Friends")
                        ProfileStatItem(value: viewModel.user.mutualFriendCount, label: "Mutual")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                if !viewModel.user.bio.isEmpty {
                    ProfileBioView(bio: viewModel.user.bio)
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                }

                actionButtons
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                ProfilePostsSection(isLoading: viewModel.isLoadingPosts, posts: viewModel.userPosts) {
                    friendPostsEmptyState
                }
                .padding(.top, 16)
            }
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
            viewModel.loadFullProfile()
            viewModel.loadPosts()
        }
        .onChange(of: store.status(for: viewModel.user)) { _, _ in viewModel.loadPosts() }
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
                    HStack(spacing: 6) {
                        Image(systemName: "person.badge.plus")
                            .font(.subheadline)
                        Text("Add Friend")
                            .font(.subheadline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundStyle(Color(.systemBackground))
                    .background(Color.primary, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

            case .pendingSent:
                Button {
                    viewModel.cancelRequest(store: store)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.subheadline)
                        Text("Request Pending")
                            .font(.subheadline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundStyle(.secondary)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

            case .pendingReceived:
                HStack(spacing: 10) {
                    Button {
                        viewModel.acceptRequest(store: store)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark")
                                .font(.subheadline)
                            Text("Accept")
                                .font(.subheadline.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundStyle(Color(.systemBackground))
                        .background(Color.primary, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)

                    Button {
                        viewModel.declineRequest(store: store)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "xmark")
                                .font(.subheadline)
                            Text("Decline")
                                .font(.subheadline.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundStyle(.secondary)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }

            case .friends:
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.subheadline)
                    Text("Friends")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    // MARK: - Empty State

    private var friendPostsEmptyState: some View {
        Group {
            if store.status(for: viewModel.user) == .friends {
                ProfilePostsEmptyState(
                    icon: "photo.on.rectangle.angled",
                    title: "No posts yet"
                )
            } else {
                ProfilePostsEmptyState(
                    icon: "photo.on.rectangle.angled",
                    title: "No public posts",
                    subtitle: "Add \(viewModel.user.displayName) as a friend to see more."
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
    .environment(AuthManager())
}
