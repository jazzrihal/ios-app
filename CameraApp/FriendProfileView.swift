import SwiftUI

struct FriendProfileView: View {
    let user: User
    @Environment(FriendsStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var showRemoveConfirmation = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // ── Header ──
                profileHeader

                // ── Stats ──
                statsSection

                // ── Bio ──
                bioSection

                // ── Actions ──
                actionButtons

                Spacer()
            }
            .padding(.top, 20)
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Remove Friend", isPresented: $showRemoveConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                withAnimation(.spring(duration: 0.3)) {
                    store.removeFriend(user)
                }
                dismiss()
            }
        } message: {
            Text("Are you sure you want to remove \(user.displayName) from your friends? This cannot be undone.")
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        VStack(spacing: 14) {
            // Avatar
            AvatarView(user: user, size: 96)
                .shadow(color: user.gradientColors.first?.opacity(0.3) ?? .clear, radius: 12, y: 4)

            // Name
            VStack(spacing: 4) {
                Text(user.displayName)
                    .font(.title2.weight(.bold))

                Text("@\(user.username)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Member since
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.caption2)
                Text("Joined \(user.joinDateFormatted)")
                    .font(.caption)
            }
            .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Stats

    private var statsSection: some View {
        HStack(spacing: 0) {
            statItem(value: "\(user.postCount)", label: "Posts")
            Divider()
                .frame(height: 36)
            statItem(value: "\(user.friendCount)", label: "Friends")
            Divider()
                .frame(height: 36)
            statItem(value: "\(user.mutualFriendCount)", label: "Mutual")
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

            Text(user.bio)
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
            let friendStatus = store.status(for: user)

            switch friendStatus {
            case .none:
                // Add Friend
                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        store.sendRequest(to: user)
                    }
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
                // Cancel Request
                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        store.cancelRequest(to: user)
                    }
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
                // Accept / Decline
                HStack(spacing: 12) {
                    Button {
                        withAnimation(.spring(duration: 0.3)) {
                            store.acceptRequest(from: user)
                        }
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
                        withAnimation(.spring(duration: 0.3)) {
                            store.declineRequest(from: user)
                        }
                        dismiss()
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
                // Message Button
                NavigationLink(destination: chatDestination) {
                    HStack(spacing: 8) {
                        Image(systemName: "bubble.left.fill")
                        Text("Message")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.blue, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
                }
                .padding(.horizontal, 16)

                // Remove Friend
                Button {
                    showRemoveConfirmation = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "person.badge.minus")
                        Text("Remove Friend")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .padding(.horizontal, 16)
            }
        }
    }

    @ViewBuilder
    private var chatDestination: some View {
        if let conversation = store.conversations.first(where: { $0.id == user.id }) {
            ChatView(conversation: conversation)
        } else {
            ChatView(conversation: Conversation(
                id: user.id,
                user: user,
                messages: [],
                unreadCount: 0
            ))
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        FriendProfileView(user: User.sampleFriends().first!)
    }
    .environment(FriendsStore())
}
