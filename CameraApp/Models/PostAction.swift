import Foundation

// MARK: - Post Action

enum PostAction: CaseIterable, Hashable {
    case like, share, jump, pinToProfile

    var iconName: String {
        switch self {
        case .like: return "heart"
        case .share: return "square.and.arrow.up"
        case .jump: return "scope"
        case .pinToProfile: return "pin"
        }
    }

    var label: String {
        switch self {
        case .like: return "Like"
        case .share: return "Share"
        case .jump: return "Jump"
        case .pinToProfile: return "Pin"
        }
    }
}
