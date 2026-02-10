import Foundation

// MARK: - Post Scope

enum PostScope: String, CaseIterable, Identifiable {
    case `private` = "Private"
    case friends = "Friends"
    case `public` = "Public"

    var id: String {
        rawValue
    }

    var icon: String {
        switch self {
        case .private: "lock.fill"
        case .friends: "person.2.fill"
        case .public: "globe"
        }
    }

    var subtitle: String {
        switch self {
        case .private: "Only you"
        case .friends: "Your friends"
        case .public: "Everyone"
        }
    }
}
