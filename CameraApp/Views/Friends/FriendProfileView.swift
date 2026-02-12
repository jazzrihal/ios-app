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
            VStack(spacing: 24) {
                profileHeader
                statsSection
                bioSection
                actionButtons

                postsSection

                if store.status(for: viewModel.user) == .friends {
                    Button {
                        viewModel.showRemoveConfirmation = true
                    } label: {
                        Text("Remove Friend")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
            .padding(.top, 20)
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.loadPosts() }
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

    // MARK: - Profile Header

    private var profileHeader: some View {
        VStack(spacing: 14) {
            AvatarView(user: viewModel.user, size: 96)
                .shadow(color: viewModel.user.gradientColors.first?.opacity(0.3) ?? .clear, radius: 12, y: 4)

            VStack(spacing: 4) {
                Text(viewModel.user.displayName)
                    .font(.title2.weight(.bold))

                Text("@\(viewModel.user.username)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.caption2)
                Text("Joined \(viewModel.user.joinDateFormatted)")
                    .font(.caption)
            }
            .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Stats

    private var statsSection: some View {
        HStack(spacing: 0) {
            statItem(value: "\(viewModel.user.postCount)", label: "Posts")
            Divider()
                .frame(height: 36)
            statItem(value: "\(viewModel.user.friendCount)", label: "Friends")
            Divider()
                .frame(height: 36)
            statItem(value: "\(viewModel.user.mutualFriendCount)", label: "Mutual")
        }
        .padding(.vertical, 16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.weight(.bold))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Bio

    private var bioSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("About", systemImage: "text.quote")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(viewModel.user.bio)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            let friendStatus = store.status(for: viewModel.user)

            switch friendStatus {
            case .none:
                Button {
                    viewModel.sendRequest(store: store)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "person.badge.plus")
                        Text("Add Friend")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .padding(.horizontal, 16)

            case .pendingSent:
                Button {
                    viewModel.cancelRequest(store: store)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "clock")
                        Text("Request Pending")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.bordered)
                .tint(.secondary)
                .padding(.horizontal, 16)

                Text("Tap to cancel request")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

            case .pendingReceived:
                HStack(spacing: 12) {
                    Button {
                        viewModel.acceptRequest(store: store)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark")
                            Text("Accept")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)

                    Button {
                        viewModel.declineRequest(store: store)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "xmark")
                            Text("Decline")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
                .padding(.horizontal, 16)

            case .friends:
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Friends")
                        .fontWeight(.semibold)
                }
                .foregroundStyle(.green)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Posts Section

    private var postsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Posts", systemImage: "photo.on.rectangle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(viewModel.userPosts.count)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)

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
        VStack(spacing: 10) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 32))
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
