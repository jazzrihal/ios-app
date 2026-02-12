import Foundation

// MARK: - Post Action

enum PostAction: CaseIterable, Hashable {
    case like, share, jump, pinToProfile

    var iconName: String {
        switch self {
        case .like: "heart"
        case .share: "square.and.arrow.up"
        case .jump: "scope"
        case .pinToProfile: "pin"
        }
    }

    var label: String {
        switch self {
        case .like: "Like"
        case .share: "Share"
        case .jump: "Jump"
        case .pinToProfile: "Pin"
        }
    }
}
