import SwiftUI

// MARK: - Activity View

struct ActivityView: View {
    @Binding var unreadBadge: Int
    @State private var viewModel: ActivityViewModel

    init(repository: DefaultNotificationRepository, unreadBadge: Binding<Int>) {
        let vm = ActivityViewModel()
        vm.repository = repository
        _viewModel = State(initialValue: vm)
        _unreadBadge = unreadBadge
    }

    var body: some View {
        Group {
            if viewModel.isLoading, viewModel.notifications.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.notifications.isEmpty {
                EmptyStateView(
                    icon: "bell",
                    title: "No activity yet",
                    subtitle: "Likes and friend requests will show up here."
                )
            } else {
                notificationList
            }
        }
        .navigationTitle("Activity")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewModel.unreadCount > 0 {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Mark All Read") {
                        viewModel.markAllRead()
                        unreadBadge = 0
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .task { await viewModel.load() }
    }

    // MARK: - List

    private var notificationList: some View {
        List {
            ForEach(viewModel.notifications) { notification in
                ActivityRow(notification: notification) {
                    viewModel.markRead(id: notification.id)
                }
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(
                    top: AppStyle.Spacing.small,
                    leading: AppStyle.Padding.screenHorizontal,
                    bottom: AppStyle.Spacing.small,
                    trailing: AppStyle.Padding.screenHorizontal
                ))
            }

            if viewModel.hasMorePages {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
                    .onAppear { Task { await viewModel.loadMore() } }
            }
        }
        .listStyle(.plain)
        .refreshable { await viewModel.refresh() }
    }
}

// MARK: - Activity Row

private struct ActivityRow: View {
    let notification: AppNotification
    let onTap: () -> Void

    private var actorUser: User {
        User(
            id: notification.actorId,
            username: notification.actorUsername,
            displayName: notification.actorDisplayName,
            bio: "",
            gradientColors: notification.actorGradientColors,
            joinDate: Date(),
            postCount: 0,
            friendCount: 0,
            mutualFriendCount: 0
        )
    }

    private var messageSuffix: String {
        switch notification.type {
        case .friendRequestReceived: " sent you a friend request."
        case .friendRequestAccepted: " accepted your friend request."
        case .postLiked: " liked your photo."
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AppStyle.Spacing.row) {
                AvatarView(user: actorUser, size: AppStyle.IconSize.avatarSmall)

                VStack(alignment: .leading, spacing: AppStyle.Spacing.tight) {
                    (
                        Text(notification.actorDisplayName)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                            + Text(messageSuffix)
                            .foregroundStyle(.secondary)
                    )
                    .font(.subheadline)
                    .lineLimit(3)

                    Text(notification.createdAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                if !notification.isRead {
                    Circle()
                        .fill(Color.primary)
                        .frame(width: 8, height: 8)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
