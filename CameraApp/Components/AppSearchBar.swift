import SwiftUI

/// Reusable search bar with magnifying glass icon, text field, and clear/loading indicator.
struct AppSearchBar: View {
    @Binding var text: String
    var placeholder: String = "Search…"
    var isLoading: Bool = false
    var capitalization: TextInputAutocapitalization = .never
    var focusField: FocusState<Bool>.Binding?
    var onClear: (() -> Void)?

    var body: some View {
        HStack(spacing: AppStyle.Spacing.row) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.subheadline)

            textField

            trailingAccessory
        }
        .padding(.horizontal, AppStyle.Padding.cardInner)
        .padding(.vertical, AppStyle.Spacing.row)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: AppStyle.CornerRadius.control)
        )
    }

    // MARK: - Text Field

    @ViewBuilder private var textField: some View {
        let field = TextField(placeholder, text: $text)
            .font(.subheadline)
            .autocorrectionDisabled()
            .textInputAutocapitalization(capitalization)

        if let focusField {
            field.focused(focusField)
        } else {
            field
        }
    }

    // MARK: - Trailing Accessory

    @ViewBuilder private var trailingAccessory: some View {
        if isLoading {
            ProgressView()
                .controlSize(.mini)
        } else if !text.isEmpty {
            Button {
                if let onClear {
                    onClear()
                } else {
                    text = ""
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }
            .buttonStyle(.plain)
        }
    }
}
