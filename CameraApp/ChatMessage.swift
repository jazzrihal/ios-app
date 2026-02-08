import Foundation

struct ChatMessage: Identifiable, Equatable {
    let id: UUID
    let senderId: UUID
    let text: String
    let timestamp: Date
    let isFromCurrentUser: Bool

    var timeFormatted: String {
        timestamp.formatted(.dateTime.hour().minute())
    }

    var dateSectionLabel: String {
        if Calendar.current.isDateInToday(timestamp) {
            return "Today"
        } else if Calendar.current.isDateInYesterday(timestamp) {
            return "Yesterday"
        } else {
            return timestamp.formatted(.dateTime.month(.abbreviated).day())
        }
    }
}

// MARK: - Conversation

struct Conversation: Identifiable, Equatable {
    let id: UUID  // same as the other user's ID
    let user: User
    var messages: [ChatMessage]
    var unreadCount: Int

    var lastMessage: ChatMessage? {
        messages.last
    }

    var lastMessagePreview: String {
        guard let msg = lastMessage else { return "No messages yet" }
        if msg.isFromCurrentUser {
            return "You: \(msg.text)"
        }
        return msg.text
    }

    var lastMessageTime: String {
        guard let msg = lastMessage else { return "" }
        let now = Date()
        let diff = now.timeIntervalSince(msg.timestamp)

        if diff < 60 {
            return "Now"
        } else if diff < 3600 {
            return "\(Int(diff / 60))m"
        } else if diff < 86400 {
            return "\(Int(diff / 3600))h"
        } else {
            return msg.timestamp.formatted(.dateTime.month(.abbreviated).day())
        }
    }
}

// MARK: - Sample Data

extension Conversation {
    static func sampleConversations(friends: [User]) -> [Conversation] {
        let now = Date()
        let currentUserId = User.currentUser.id

        let sampleChats: [[String]] = [
            [
                "Hey! Did you see that sunset yesterday?",
                "Yes! It was incredible, I got some great shots",
                "You should post them! The colors were unreal",
                "Just uploaded one. Check it out!",
                "Wow that's stunning. Where were you?",
                "Rooftop near the Marina. Best spot in the city",
            ],
            [
                "Are you going to the photo walk this weekend?",
                "Thinking about it! Where is it?",
                "Golden Gate Park, Saturday morning at 8am",
                "Count me in! Should I bring my wide angle?",
                "Definitely. The gardens are gorgeous this time of year",
            ],
            [
                "Just arrived in Tokyo!",
                "No way! How is it?",
                "Absolutely mind-blowing. The streets at night are pure magic",
                "So jealous. Send me some photos!",
                "Will do. Heading to Shibuya crossing now",
                "Get the long exposure shot!",
                "Already on it haha",
            ],
            [
                "Thanks for the photography tips!",
                "Anytime! Let me know if you need anything else",
                "Actually, what lens do you recommend for street photography?",
                "I love my 35mm. Perfect focal length for street",
                "Good call. Ordering one now",
            ],
            [
                "Your latest post is amazing!",
                "Thank you so much!",
                "How did you get that lighting?",
                "Natural light through the window, around 4pm golden hour",
                "I need to try that technique",
            ],
        ]

        var conversations: [Conversation] = []

        for (index, friend) in friends.enumerated() {
            guard index < sampleChats.count else { break }

            let chatLines = sampleChats[index]
            var messages: [ChatMessage] = []

            for (msgIndex, text) in chatLines.enumerated() {
                let isFromMe = msgIndex % 2 == 1
                let minutesAgo = Double((chatLines.count - msgIndex) * 15 + Int.random(in: 0...10))
                let hoursAgo = Double(index) * 4.0

                messages.append(ChatMessage(
                    id: UUID(),
                    senderId: isFromMe ? currentUserId : friend.id,
                    text: text,
                    timestamp: now.addingTimeInterval(-(hoursAgo * 3600 + minutesAgo * 60)),
                    isFromCurrentUser: isFromMe
                ))
            }

            conversations.append(Conversation(
                id: friend.id,
                user: friend,
                messages: messages,
                unreadCount: index == 0 ? 2 : (index == 2 ? 1 : 0)
            ))
        }

        return conversations.sorted {
            ($0.lastMessage?.timestamp ?? .distantPast) > ($1.lastMessage?.timestamp ?? .distantPast)
        }
    }
}
