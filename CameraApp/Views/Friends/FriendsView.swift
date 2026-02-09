import SwiftUI

// MARK: - Friends Tab Sections

enum FriendsSection: String, CaseIterable {
    case friends = "Friends"
    case addFriend = "Add Friend"
}

// MARK: - Friends View

struct FriendsView: View {
    @Environment(FriendsStore.self) private var store
    @State private var selectedSection: FriendsSection = .friends
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // ── Segmented Picker ──
                sectionPicker

                // ── Content ──
                switch selectedSection {
                case .friends:
                    friendsListSection
                case .addFriend:
                    addFriendSection
                }
            }
            .navigationTitle("Friends")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Section Picker

    private var sectionPicker: some View {
        HStack(spacing: 0) {
            ForEach(FriendsSection.allCases, id: \.self) { section in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedSection = section
                        searchText = ""
                    }
                } label: {
                    VStack(spacing: 6) {
                        HStack(spacing: 4) {
                            Text(section.rawValue)
                                .font(.subheadline.weight(.semibold))

                            if section == .friends && !store.incomingRequests.isEmpty {
                                badgeView(count: store.incomingRequests.count)
                            }

                        }

                        Rectangle()
                            .fill(selectedSection == section ? Color.blue : Color.clear)
                            .frame(height: 2)
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(selectedSection == section ? .primary : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    private func badgeView(count: Int) -> some View {
        Text("\(count)")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.red, in: Capsule())
    }

    // MARK: - Friends List Section

    private var friendsListSection: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // ── Search ──
                searchBar(placeholder: "Search friends…")
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                // ── Incoming Requests ──
                if !store.incomingRequests.isEmpty && searchText.isEmpty {
                    incomingRequestsSection
                }

                // ── Friends List ──
                let filtered = store.searchFriends(query: searchText)
                if filtered.isEmpty {
                    emptyState(
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
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 24)
        }
    }

    private var incomingRequestsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "person.badge.plus")
                    .foregroundStyle(.blue)
                Text("Friend Requests")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(store.incomingRequests.count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.blue, in: Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            ForEach(store.incomingRequests) { user in
                IncomingRequestRow(user: user)
            }
            .padding(.horizontal, 16)

            Divider()
                .padding(.horizontal, 16)
                .padding(.top, 4)
        }
    }

    // MARK: - Add Friend Section

    private var addFriendSection: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // ── Search ──
                searchBar(placeholder: "Search by username or name…")
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                if searchText.isEmpty {
                    // ── Prompt ──
                    VStack(spacing: 12) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 36))
                            .foregroundStyle(.tertiary)
                        Text("Add a Friend")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text("Search by username or display name\nto find and add friends")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 60)
                    .padding(.horizontal, 32)
                } else {
                    // ── Results ──
                    let results = store.searchUsers(query: searchText)
                    if results.isEmpty {
                        emptyState(
                            icon: "magnifyingglass",
                            title: "No People Found",
                            subtitle: "Try a different username or name"
                        )
                    } else {
                        ForEach(results) { user in
                            NavigationLink(destination: FriendProfileView(user: user)) {
                                DiscoverUserRow(user: user)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
            .padding(.bottom, 24)
        }
    }

    // MARK: - Shared Components

    private func searchBar(placeholder: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.subheadline)

            TextField(placeholder, text: $searchText)
                .font(.subheadline)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    private func emptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 60)
        .padding(.horizontal, 32)
    }
}

// MARK: - Friend Row

struct FriendRow: View {
    let user: User

    var body: some View {
        HStack(spacing: 14) {
            AvatarView(user: user, size: 48)

            VStack(alignment: .leading, spacing: 4) {
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
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.top, 8)
    }
}

// MARK: - Incoming Request Row

struct IncomingRequestRow: View {
    let user: User
    @Environment(FriendsStore.self) private var store

    var body: some View {
        HStack(spacing: 12) {
            NavigationLink(destination: FriendProfileView(user: user)) {
                AvatarView(user: user, size: 44)
            }

            VStack(alignment: .leading, spacing: 2) {
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
                withAnimation(.spring(duration: 0.3)) {
                    store.acceptRequest(from: user)
                }
            } label: {
                Text("Accept")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.blue, in: Capsule())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)

            Button {
                withAnimation(.spring(duration: 0.3)) {
                    store.declineRequest(from: user)
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .padding(.top, 4)
    }
}

// MARK: - Discover User Row

struct DiscoverUserRow: View {
    let user: User
    @Environment(FriendsStore.self) private var store

    var body: some View {
        HStack(spacing: 14) {
            AvatarView(user: user, size: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(user.displayName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                HStack(spacing: 4) {
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
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.top, 8)
    }

    @ViewBuilder
    private var statusButton: some View {
        let friendStatus = store.status(for: user)

        switch friendStatus {
        case .none:
            Button {
                withAnimation(.spring(duration: 0.3)) {
                    store.sendRequest(to: user)
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "person.badge.plus")
                        .font(.caption2)
                    Text("Add")
                        .font(.caption.weight(.semibold))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.blue, in: Capsule())
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)

        case .pendingSent:
            Button {
                withAnimation(.spring(duration: 0.3)) {
                    store.cancelRequest(to: user)
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text("Pending")
                        .font(.caption.weight(.semibold))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

        case .pendingReceived:
            Button {
                withAnimation(.spring(duration: 0.3)) {
                    store.acceptRequest(from: user)
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark")
                        .font(.caption2)
                    Text("Accept")
                        .font(.caption.weight(.semibold))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.green, in: Capsule())
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)

        case .friends:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption2)
                Text("Friends")
                    .font(.caption.weight(.semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .foregroundStyle(.green)
        }
    }
}

// MARK: - Avatar View

struct AvatarView: View {
    let user: User
    let size: CGFloat

    var body: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: user.gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size, height: size)
            .overlay {
                Text(user.initials)
                    .font(.system(size: size * 0.35, weight: .bold))
                    .foregroundStyle(.white)
            }
    }
}

// MARK: - Preview

#Preview {
    FriendsView()
        .environment(FriendsStore())
}
