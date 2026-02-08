import SwiftUI

struct ChatView: View {
    let conversation: Conversation
    @Environment(FriendsStore.self) private var store
    @State private var messageText = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // ── Messages ──
            messagesScrollView

            // ── Input Bar ──
            inputBar
        }
        .navigationTitle(conversation.user.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(destination: FriendProfileView(user: conversation.user)) {
                    AvatarView(user: conversation.user, size: 30)
                }
            }
        }
        .onAppear {
            store.markAsRead(userId: conversation.id)
        }
    }

    // MARK: - Messages

    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 4) {
                    // Group messages by date
                    ForEach(groupedMessages, id: \.date) { group in
                        dateSeparator(group.date)

                        ForEach(group.messages) { message in
                            MessageBubble(message: message, user: conversation.user)
                                .id(message.id)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: currentMessages.count) { _, _ in
                if let lastId = currentMessages.last?.id {
                    withAnimation(.spring(duration: 0.3)) {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
            .onAppear {
                if let lastId = currentMessages.last?.id {
                    proxy.scrollTo(lastId, anchor: .bottom)
                }
            }
        }
    }

    private var currentMessages: [ChatMessage] {
        store.conversations.first(where: { $0.id == conversation.id })?.messages ?? conversation.messages
    }

    private struct MessageGroup {
        let date: String
        let messages: [ChatMessage]
    }

    private var groupedMessages: [MessageGroup] {
        let messages = currentMessages
        var groups: [MessageGroup] = []
        var currentDate = ""
        var currentBatch: [ChatMessage] = []

        for message in messages {
            let dateLabel = message.dateSectionLabel
            if dateLabel != currentDate {
                if !currentBatch.isEmpty {
                    groups.append(MessageGroup(date: currentDate, messages: currentBatch))
                }
                currentDate = dateLabel
                currentBatch = [message]
            } else {
                currentBatch.append(message)
            }
        }

        if !currentBatch.isEmpty {
            groups.append(MessageGroup(date: currentDate, messages: currentBatch))
        }

        return groups
    }

    private func dateSeparator(_ label: String) -> some View {
        Text(label)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 10) {
                TextField("Message…", text: $messageText, axis: .vertical)
                    .lineLimit(1...5)
                    .font(.subheadline)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .focused($isInputFocused)

                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(
                            messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? .secondary
                                : .blue
                        )
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.bar)
        }
    }

    // MARK: - Actions

    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        store.sendMessage(to: conversation.id, text: text)
        messageText = ""
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ChatMessage
    let user: User

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isFromCurrentUser {
                Spacer(minLength: 60)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(message.text)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(
                                colors: [.blue, .blue.opacity(0.85)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: BubbleShape(isFromCurrentUser: true)
                        )

                    Text(message.timeFormatted)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.trailing, 4)
                }
            } else {
                AvatarView(user: user, size: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(message.text)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            Color(.systemGray5),
                            in: BubbleShape(isFromCurrentUser: false)
                        )

                    Text(message.timeFormatted)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 4)
                }
                Spacer(minLength: 60)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Bubble Shape

struct BubbleShape: Shape {
    let isFromCurrentUser: Bool

    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 18
        let tailRadius: CGFloat = 6

        var path = Path()

        if isFromCurrentUser {
            // Top-left corner
            path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
            // Top edge
            path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
            // Top-right corner
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.minY + radius),
                control: CGPoint(x: rect.maxX, y: rect.minY)
            )
            // Right edge
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - tailRadius))
            // Bottom-right (sharp for tail)
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX - tailRadius, y: rect.maxY),
                control: CGPoint(x: rect.maxX, y: rect.maxY)
            )
            // Bottom edge
            path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
            // Bottom-left corner
            path.addQuadCurve(
                to: CGPoint(x: rect.minX, y: rect.maxY - radius),
                control: CGPoint(x: rect.minX, y: rect.maxY)
            )
            // Left edge
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
            // Top-left corner
            path.addQuadCurve(
                to: CGPoint(x: rect.minX + radius, y: rect.minY),
                control: CGPoint(x: rect.minX, y: rect.minY)
            )
        } else {
            // Top-left corner
            path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
            // Top edge
            path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
            // Top-right corner
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.minY + radius),
                control: CGPoint(x: rect.maxX, y: rect.minY)
            )
            // Right edge
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
            // Bottom-right corner
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX - radius, y: rect.maxY),
                control: CGPoint(x: rect.maxX, y: rect.maxY)
            )
            // Bottom edge
            path.addLine(to: CGPoint(x: rect.minX + tailRadius, y: rect.maxY))
            // Bottom-left (sharp for tail)
            path.addQuadCurve(
                to: CGPoint(x: rect.minX, y: rect.maxY - tailRadius),
                control: CGPoint(x: rect.minX, y: rect.maxY)
            )
            // Left edge
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
            // Top-left corner
            path.addQuadCurve(
                to: CGPoint(x: rect.minX + radius, y: rect.minY),
                control: CGPoint(x: rect.minX, y: rect.minY)
            )
        }

        return path
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ChatView(
            conversation: Conversation.sampleConversations(
                friends: User.sampleFriends()
            ).first!
        )
    }
    .environment(FriendsStore())
}
