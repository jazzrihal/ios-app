import NukeUI
import SwiftUI

/// Standardized three-state remote image: loaded, error placeholder, loading spinner.
/// The caller controls sizing via `.frame()` / `.aspectRatio()` — this view handles state rendering.
struct RemoteImage: View {
    let url: URL?
    var contentMode: ContentMode = .fill

    var body: some View {
        LazyImage(url: url) { state in
            if let image = state.image {
                if contentMode == .fill {
                    Color.clear
                        .overlay {
                            image
                                .resizable()
                                .scaledToFill()
                        }
                        .clipped()
                } else {
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .clipped()
                }
            } else if state.error != nil {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .overlay {
                        Image(systemName: "photo.badge.exclamationmark")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
            } else {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .overlay { ProgressView() }
            }
        }
    }
}
