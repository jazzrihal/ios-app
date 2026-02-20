import SwiftUI

/// Gradient circle avatar with user initials.
struct AvatarView: View {
    let user: User
    var size: CGFloat = AppStyle.IconSize.avatarMedium

    var body: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: user.gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size, height: size)
            .overlay {
                Text(user.initials)
                    .font(.system(size: size * 0.35, weight: .bold))
                    .foregroundStyle(.white)
            }
    }
}
