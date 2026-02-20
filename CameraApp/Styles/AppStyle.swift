import SwiftUI

/// Single source of truth for the app's visual design tokens.
enum AppStyle {
    // MARK: - Corner Radii

    enum CornerRadius {
        static let badge: CGFloat = 6
        static let pill: CGFloat = 8
        static let control: CGFloat = 10
        static let card: CGFloat = 14
        static let overlay: CGFloat = 20
    }

    // MARK: - Spacing

    enum Spacing {
        static let grid: CGFloat = 2
        static let tight: CGFloat = 4
        static let compact: CGFloat = 6
        static let small: CGFloat = 8
        static let row: CGFloat = 10
        static let medium: CGFloat = 12
        static let large: CGFloat = 24
    }

    // MARK: - Padding

    enum Padding {
        static let screenHorizontal: CGFloat = 16
        static let cardInner: CGFloat = 12
        static let buttonVertical: CGFloat = 14
        static let pillHorizontal: CGFloat = 12
        static let pillVertical: CGFloat = 6
        static let emptyStateTop: CGFloat = 60
        static let emptyStateHorizontal: CGFloat = 32
    }

    // MARK: - Icon Sizes

    enum IconSize {
        static let emptyStateIcon: CGFloat = 36
        static let emptyStateIconCompact: CGFloat = 28
        static let tapTarget: CGFloat = 44
        static let avatarSmall: CGFloat = 32
        static let avatarMedium: CGFloat = 48
        static let avatarLarge: CGFloat = 72
    }

    // MARK: - Shadows

    enum Shadow {
        static func card(_ view: some View) -> some View {
            view.shadow(color: .black.opacity(0.08), radius: 8, y: 4)
        }

        static func avatar(_ view: some View, accentColor: Color) -> some View {
            view.shadow(color: accentColor.opacity(0.25), radius: 8, y: 3)
        }

        static func overlay(_ view: some View) -> some View {
            view.shadow(color: .black.opacity(0.15), radius: 10, y: 5)
        }

        static func annotation(_ view: some View) -> some View {
            view.shadow(color: .black.opacity(0.2), radius: 4, y: 2)
        }
    }

    // MARK: - Animation

    enum Animation {
        static let transition = SwiftUI.Animation.easeInOut(duration: 0.2)
        static let spring = SwiftUI.Animation.spring(duration: 0.3)
        static let press = SwiftUI.Animation.easeInOut(duration: 0.15)
    }
}
