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

    /// The lowercased value used when inserting into the database.
    var databaseValue: String {
        rawValue.lowercased()
    }

    /// Creates a `PostScope` from a lowercased database string (e.g. `"friends"`).
    /// Falls back to `.public` for unknown values.
    init(serverValue: String) {
        switch serverValue.lowercased() {
        case "private": self = .private
        case "friends": self = .friends
        case "public": self = .public
        default: self = .public
        }
    }
}
