import SwiftUI

struct FriendProfileView: View {
    @Environment(FriendsStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: FriendProfileViewModel

    private let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)

    init(user: User) {
        _viewModel = State(initialValue: FriendProfileViewModel(user: user))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                profileHeader
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                if !viewModel.user.bio.isEmpty {
                    bioSection
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                }

                actionButtons
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                postsSection
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

    // MARK: - Profile Header (compact horizontal)

    private var profileHeader: some View {
        HStack(spacing: 16) {
            AvatarView(user: viewModel.user, size: 72)
                .shadow(color: viewModel.user.gradientColors.first?.opacity(0.25) ?? .clear, radius: 8, y: 3)

            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.user.displayName)
                        .font(.title3.weight(.bold))

                    Text("@\(viewModel.user.username)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 14) {
                    statItem(value: viewModel.userPosts.count, label: "Posts")
                    statItem(value: viewModel.user.friendCount, label: "Friends")
                    statItem(value: viewModel.user.mutualFriendCount, label: "Mutual")
                }
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - Stats

    private func statItem(value: Int, label: String) -> some View {
        HStack(spacing: 4) {
            Text("\(value)")
                .font(.subheadline.weight(.bold))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Bio

    private var bioSection: some View {
        Text(viewModel.user.bio)
            .font(.subheadline)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lineLimit(2)
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

    // MARK: - Posts Section

    private var postsSection: some View {
        VStack(spacing: 0) {
            Divider()

            if viewModel.userPosts.isEmpty {
                postsEmptyState
            } else {
                postsGrid
            }
        }
    }

    private var postsGrid: some View {
        LazyVGrid(columns: gridColumns, spacing: 2) {
            ForEach(Array(viewModel.userPosts.enumerated()), id: \.element.id) { index, post in
                NavigationLink(destination: PostDetailView(posts: viewModel.userPosts, initialIndex: index, queryDate: Date())) {
                    AsyncImage(url: post.imageURL) { phase in
                        switch phase {
                        case .empty:
                            Rectangle()
                                .fill(Color(.systemGray5))
                                .overlay { ProgressView() }
                        case let .success(image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            Rectangle()
                                .fill(Color(.systemGray5))
                                .overlay {
                                    Image(systemName: "photo.badge.exclamationmark")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .aspectRatio(1, contentMode: .fill)
                    .clipped()
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var postsEmptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)

            Text(store.status(for: viewModel.user) == .friends ? "No posts yet" : "No public posts")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if store.status(for: viewModel.user) != .friends {
                Text("Add \(viewModel.user.displayName) as a friend to see more.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
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
