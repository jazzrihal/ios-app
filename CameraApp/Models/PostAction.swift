import Foundation

// MARK: - Post Action

enum PostAction: CaseIterable, Hashable {
    case jump, share, pinToProfile, like

    var iconName: String {
        switch self {
        case .like: "heart"
        case .share: "square.and.arrow.up"
        case .jump: "scope"
        case .pinToProfile: "pin"
        }
    }

    var activeIconName: String {
        switch self {
        case .like: "heart.fill"
        case .share: "square.and.arrow.up"
        case .jump: "scope"
        case .pinToProfile: "pin.fill"
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

    var activeLabel: String {
        switch self {
        case .like: "Unlike"
        case .share: "Share"
        case .jump: "Jump"
        case .pinToProfile: "Unpin"
        }
    }

    var accessibilityId: String {
        switch self {
        case .jump: "JumpButton"
        case .share: "ShareButton"
        case .pinToProfile: "PinButton"
        case .like: "LikeButton"
        }
    }
}
