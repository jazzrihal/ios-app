import SwiftUI

/// Reusable empty-state placeholder with icon, title, and optional subtitle.
struct EmptyStateView: View {
    let icon: String
    let title: String
    var subtitle: String?
    var style: Style = .prominent

    enum Style {
        case prominent
        case compact
    }

    var body: some View {
        VStack(spacing: style == .prominent ? AppStyle.Spacing.medium : AppStyle.Spacing.small) {
            Image(systemName: icon)
                .font(.system(size: iconSize))
                .foregroundStyle(.tertiary)

            Text(title)
                .font(titleFont)
                .foregroundStyle(.secondary)

            if let subtitle {
                Text(subtitle)
                    .font(subtitleFont)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(edgePadding)
    }

    // MARK: - Style-dependent values

    private var iconSize: CGFloat {
        switch style {
        case .prominent: AppStyle.IconSize.emptyStateIcon
        case .compact: AppStyle.IconSize.emptyStateIconCompact
        }
    }

    private var titleFont: Font {
        switch style {
        case .prominent: .headline
        case .compact: .subheadline
        }
    }

    private var subtitleFont: Font {
        switch style {
        case .prominent: .subheadline
        case .compact: .caption
        }
    }

    private var edgePadding: EdgeInsets {
        switch style {
        case .prominent:
            EdgeInsets(
                top: AppStyle.Padding.emptyStateTop,
                leading: AppStyle.Padding.emptyStateHorizontal,
                bottom: 0,
                trailing: AppStyle.Padding.emptyStateHorizontal
            )
        case .compact:
            EdgeInsets(top: 40, leading: 0, bottom: 40, trailing: 0)
        }
    }
}
