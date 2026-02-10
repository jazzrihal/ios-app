import MapKit
import SwiftUI

struct MomentsView: View {
    @Environment(MomentsStore.self) private var store
    @State private var showMap = false

    var body: some View {
        NavigationStack {
            Group {
                if store.moments.isEmpty {
                    ContentUnavailableView(
                        "No Moments Yet",
                        systemImage: "clock.badge.questionmark",
                        description: Text("Save moments from the Explore tab to see them here.")
                    )
                } else if showMap {
                    MomentsMapView(
                        moments: sortedMoments,
                        onNavigate: navigateToExplore
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !store.moments.isEmpty {
                        Picker("View Mode", selection: $showMap) {
                            Image(systemName: "list.bullet")
                                .tag(false)
                            Image(systemName: "map")
                                .tag(true)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 100)
                    }
                }
            }
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

// MARK: - Moments Map View

struct MomentsMapView: View {
    let moments: [Moment]
    let onNavigate: (Moment) -> Void

    @State private var selectedMoment: Moment?
    @State private var cameraPosition: MapCameraPosition = .automatic

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $cameraPosition) {
                ForEach(moments) { moment in
                    Annotation(
                        moment.locationName,
                        coordinate: moment.coordinate,
                        anchor: .bottom
                    ) {
                        Button {
                            withAnimation(.spring(duration: 0.3)) {
                                selectedMoment = selectedMoment?.id == moment.id ? nil : moment
                            }
                        } label: {
                            VStack(spacing: 0) {
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [.blue.opacity(0.9), .purple.opacity(0.9)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 36, height: 36)
                                        .shadow(color: .black.opacity(0.2), radius: 4, y: 2)

                                    Image(systemName: "mappin.and.ellipse")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(.white)
                                }

                                // Triangle pointer
                                Triangle()
                                    .fill(
                                        LinearGradient(
                                            colors: [.blue.opacity(0.9), .purple.opacity(0.9)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: 12, height: 8)
                                    .offset(y: -1)
                            }
                            .scaleEffect(selectedMoment?.id == moment.id ? 1.2 : 1.0)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            .onAppear {
                fitToMoments()
            }

            // Selected moment detail card
            if let moment = selectedMoment {
                MomentDetailCard(moment: moment) {
                    onNavigate(moment)
                } onDismiss: {
                    withAnimation(.spring(duration: 0.3)) {
                        selectedMoment = nil
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
    }

    private func fitToMoments() {
        guard !moments.isEmpty else { return }

        let latitudes = moments.map(\.coordinate.latitude)
        let longitudes = moments.map(\.coordinate.longitude)

        guard let minLat = latitudes.min(),
              let maxLat = latitudes.max(),
              let minLon = longitudes.min(),
              let maxLon = longitudes.max()
        else { return }

        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2

        let spanLat = max((maxLat - minLat) * 1.4, 0.05)
        let spanLon = max((maxLon - minLon) * 1.4, 0.05)

        cameraPosition = .region(
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
                span: MKCoordinateSpan(latitudeDelta: spanLat, longitudeDelta: spanLon)
            )
        )
    }
}

// MARK: - Moment Detail Card

struct MomentDetailCard: View {
    let moment: Moment
    let onExplore: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            // Header with dismiss
            HStack {
                Image(systemName: "mappin.and.ellipse")
                    .font(.title3)
                    .foregroundStyle(.blue)

                Text(moment.locationName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                Spacer()

                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            // Details
            HStack(spacing: 16) {
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

                Spacer()
            }

            // Explore button
            Button {
                onExplore()
            } label: {
                HStack {
                    Image(systemName: "safari")
                    Text("View in Explore")
                        .font(.subheadline.weight(.medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 12)
                )
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
    }
}

// MARK: - Triangle Shape

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Preview

#Preview {
    MomentsView()
        .environment(MomentsStore())
}
