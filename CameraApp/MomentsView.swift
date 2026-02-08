import SwiftUI

struct MomentsView: View {
    @Environment(MomentsStore.self) private var store

    var body: some View {
        NavigationStack {
            Group {
                if store.moments.isEmpty {
                    ContentUnavailableView(
                        "No Moments Yet",
                        systemImage: "clock.badge.questionmark",
                        description: Text("Save moments from the Explore tab to see them here.")
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(sortedMoments) { moment in
                                MomentRow(moment: moment)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        navigateToExplore(moment)
                                    }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("Moments")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Helpers

    /// Sorted by addedAt descending (most recently added first)
    private var sortedMoments: [Moment] {
        store.moments.sorted { $0.addedAt > $1.addedAt }
    }

    private func navigateToExplore(_ moment: Moment) {
        store.pendingMoment = moment
        store.selectedTab = 0 // Explore tab
    }
}

// MARK: - Moment Row

struct MomentRow: View {
    let moment: Moment

    var body: some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.8), .purple.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)

                Image(systemName: "mappin.and.ellipse")
                    .font(.title3)
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(moment.locationName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.caption2)
                    Text(moment.dateFormatted)
                        .font(.caption)
                }
                .foregroundStyle(.secondary)

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text("Saved \(moment.addedAtFormatted)")
                        .font(.caption)
                }
                .foregroundStyle(.tertiary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Preview

#Preview {
    MomentsView()
        .environment(MomentsStore())
}
