import Foundation

// MARK: - Post Scope

enum PostScope: String, CaseIterable, Identifiable {
    case `private` = "Private"
    case friends = "Friends"
    case `public` = "Public"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .private: return "lock.fill"
        case .friends: return "person.2.fill"
        case .public: return "globe"
        }
    }

    var subtitle: String {
        switch self {
        case .private: return "Only you"
        case .friends: return "Your friends"
        case .public: return "Everyone"
        }
    }
}
