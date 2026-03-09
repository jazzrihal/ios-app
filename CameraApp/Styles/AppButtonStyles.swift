import SwiftUI

// MARK: - Primary Button

/// Full-width call-to-action: `Color.primary` background, system background foreground.
/// Automatically dims when disabled.
struct AppPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppStyle.Padding.buttonVertical)
            .foregroundStyle(isEnabled ? Color(.systemBackground) : Color(.systemGray))
            .background(
                isEnabled ? Color.primary : Color(.systemGray5),
                in: RoundedRectangle(cornerRadius: AppStyle.CornerRadius.control)
            )
    }
}

// MARK: - Secondary Button

/// Full-width secondary action: `.ultraThinMaterial` background.
struct AppSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppStyle.Padding.buttonVertical)
            .foregroundStyle(.primary)
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: AppStyle.CornerRadius.control)
            )
    }
}

// MARK: - Pill Button (Primary)

/// Small inline primary action (e.g. Accept, Add).
struct AppPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.semibold))
            .padding(.horizontal, AppStyle.Padding.pillHorizontal)
            .padding(.vertical, AppStyle.Padding.pillVertical)
            .foregroundStyle(Color(.systemBackground))
            .background(
                Color.primary,
                in: RoundedRectangle(cornerRadius: AppStyle.CornerRadius.pill)
            )
    }
}

// MARK: - Pill Button (Secondary)

/// Small inline secondary action (e.g. Pending, Cancel).
struct AppPillSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.semibold))
            .padding(.horizontal, AppStyle.Padding.pillHorizontal)
            .padding(.vertical, AppStyle.Padding.pillVertical)
            .foregroundStyle(.secondary)
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: AppStyle.CornerRadius.pill)
            )
    }
}

// MARK: - Icon Button

/// Circular icon-only button with material background.
struct AppIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(AppStyle.Spacing.small)
            .background(.ultraThinMaterial, in: Circle())
    }
}

// MARK: - Text Button

/// Subtle text-only action with no background, for low-priority shortcuts.
struct AppTextButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
            .opacity(configuration.isPressed ? 0.5 : 1.0)
            .animation(AppStyle.Animation.press, value: configuration.isPressed)
    }
}

// MARK: - Moment Card Button

/// Subtle scale + opacity press effect for card-level buttons.
struct MomentCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(AppStyle.Animation.press, value: configuration.isPressed)
    }
}

// MARK: - Dot-syntax Extensions

extension ButtonStyle where Self == AppPrimaryButtonStyle {
    static var appPrimary: AppPrimaryButtonStyle {
        .init()
    }
}

extension ButtonStyle where Self == AppSecondaryButtonStyle {
    static var appSecondary: AppSecondaryButtonStyle {
        .init()
    }
}

extension ButtonStyle where Self == AppPillButtonStyle {
    static var appPill: AppPillButtonStyle {
        .init()
    }
}

extension ButtonStyle where Self == AppPillSecondaryButtonStyle {
    static var appPillSecondary: AppPillSecondaryButtonStyle {
        .init()
    }
}

extension ButtonStyle where Self == AppTextButtonStyle {
    static var appText: AppTextButtonStyle {
        .init()
    }
}

extension ButtonStyle where Self == AppIconButtonStyle {
    static var appIcon: AppIconButtonStyle {
        .init()
    }
}

extension ButtonStyle where Self == MomentCardButtonStyle {
    static var momentCard: MomentCardButtonStyle {
        .init()
    }
}
