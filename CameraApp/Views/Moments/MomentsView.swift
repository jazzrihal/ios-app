import MapKit
import Nuke
import SwiftUI

struct MomentsView: View {
    @Environment(MomentsStore.self) private var store
    @State private var showMap = false
    @State private var prefetcher = ImagePrefetcher()

    var body: some View {
        NavigationStack {
            Group {
                if store.moments.isEmpty, !store.isLoading {
                    EmptyStateView(
                        icon: "clock.badge.questionmark",
                        title: "No Moments Yet",
                        subtitle: "Save moments from the Explore tab to see them here."
                    )
                    .frame(maxHeight: .infinity, alignment: .top)
                } else if showMap {
                    MomentsMapView(
                        moments: sortedMoments,
                        onNavigate: navigateToExplore
                    )
                } else {
                    List {
                        ForEach(sortedMoments) { moment in
                            let posts = store.nearbyPosts[moment.id] ?? []
                            MomentCard(
                                moment: moment,
                                posts: posts
                            ) {
                                navigateToExplore(moment)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    Task { await store.deleteMoment(moment) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(
                                top: AppStyle.Spacing.small,
                                leading: AppStyle.Padding.screenHorizontal,
                                bottom: AppStyle.Spacing.small,
                                trailing: AppStyle.Padding.screenHorizontal
                            ))
                            .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .overlay {
                if store.isLoading {
                    ProgressView()
                        .tint(.secondary)
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
            .onChange(of: store.nearbyPosts.keys.sorted()) { _, _ in
                let urls = store.nearbyPosts.values.flatMap { $0.map(\.imageURL) }
                prefetcher.startPrefetching(with: urls)
            }
        }
    }

    // MARK: - Helpers

    private var sortedMoments: [Moment] {
        store.moments.sorted { $0.addedAt > $1.addedAt }
    }

    private func navigateToExplore(_ moment: Moment) {
        store.pendingMoment = moment
        store.selectedTab = 0
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
                            withAnimation(AppStyle.Animation.spring) {
                                selectedMoment = selectedMoment?.id == moment.id ? nil : moment
                            }
                        } label: {
                            VStack(spacing: 0) {
                                ZStack {
                                    Circle()
                                        .fill(Color.primary.opacity(0.9))
                                        .frame(width: 36, height: 36)
                                        .shadow(color: .black.opacity(0.2), radius: 4, y: 2)

                                    Image(systemName: "mappin.and.ellipse")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(Color(.systemBackground))
                                }

                                Triangle()
                                    .fill(Color.primary.opacity(0.9))
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

            if let moment = selectedMoment {
                MomentDetailCard(moment: moment) {
                    onNavigate(moment)
                } onDismiss: {
                    withAnimation(AppStyle.Animation.spring) {
                        selectedMoment = nil
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.horizontal, AppStyle.Padding.screenHorizontal)
                .padding(.bottom, AppStyle.Padding.screenHorizontal)
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
        VStack(spacing: AppStyle.Spacing.medium) {
            HStack {
                Image(systemName: "mappin.and.ellipse")
                    .font(.title3)
                    .foregroundStyle(.primary)

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

            HStack(spacing: AppStyle.Padding.screenHorizontal) {
                HStack(spacing: AppStyle.Spacing.tight) {
                    Image(systemName: "calendar")
                        .font(.caption2)
                    Text(moment.dateFormatted)
                        .font(.caption)
                }
                .foregroundStyle(.secondary)

                HStack(spacing: AppStyle.Spacing.tight) {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text("Saved \(moment.addedAtFormatted)")
                        .font(.caption)
                }
                .foregroundStyle(.tertiary)

                Spacer()
            }

            Button {
                onExplore()
            } label: {
                HStack {
                    Image(systemName: "safari")
                    Text("View in Explore")
                }
            }
            .buttonStyle(.appPrimary)
        }
        .padding(AppStyle.Padding.screenHorizontal)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppStyle.CornerRadius.overlay))
        .overlayShadow()
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
