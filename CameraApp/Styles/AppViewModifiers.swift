import SwiftUI

// MARK: - Card Row

/// Standard card-row surface: inner padding + ultraThinMaterial background with card corner radius.
struct CardRowModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(AppStyle.Padding.cardInner)
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: AppStyle.CornerRadius.card)
            )
    }
}

// MARK: - Section Label

/// Form section label style: semibold subheadline in secondary color.
struct SectionLabelModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
    }
}

// MARK: - Card Shadow

struct CardShadowModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
    }
}

// MARK: - Overlay Shadow

struct OverlayShadowModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
    }
}

// MARK: - View Extensions

extension View {
    func cardRow() -> some View {
        modifier(CardRowModifier())
    }

    func sectionLabel() -> some View {
        modifier(SectionLabelModifier())
    }

    func cardShadow() -> some View {
        modifier(CardShadowModifier())
    }

    func overlayShadow() -> some View {
        modifier(OverlayShadowModifier())
    }
}
