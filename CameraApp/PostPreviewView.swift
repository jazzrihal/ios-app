import CoreLocation
import SwiftUI

// MARK: - Post Scope

enum PostScope: String, CaseIterable, Identifiable {
    case `private` = "Private"
    case friends = "Friends"
    case `public` = "Public"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .private: return "lock.fill"
        case .friends: return "person.2.fill"
        case .public: return "globe"
        }
    }

    var subtitle: String {
        switch self {
        case .private: return "Only you"
        case .friends: return "Your friends"
        case .public: return "Everyone"
        }
    }
}

// MARK: - Location Manager (low accuracy)

@Observable
class PostLocationManager: NSObject, CLLocationManagerDelegate {
    var locationName: String?
    var isLoading = false
    var coordinate: CLLocationCoordinate2D?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyReduced
    }

    func requestLocation() {
        isLoading = true
        let status = manager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.requestLocation()
        } else if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else {
            isLoading = false
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard isLoading else { return }
        let status = manager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.requestLocation()
        } else if status != .notDetermined {
            isLoading = false
        }
    }

    func locationManager(
        _ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]
    ) {
        guard let location = locations.first else {
            isLoading = false
            return
        }

        coordinate = location.coordinate

        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { placemarks, _ in
            self.isLoading = false
            if let placemark = placemarks?.first {
                let city = placemark.locality
                let area = placemark.administrativeArea
                let country = placemark.country
                if let city, let area {
                    self.locationName = "\(city), \(area)"
                } else if let city, let country {
                    self.locationName = "\(city), \(country)"
                } else if let area, let country {
                    self.locationName = "\(area), \(country)"
                } else if let country {
                    self.locationName = country
                } else {
                    self.locationName = String(
                        format: "%.4f, %.4f",
                        location.coordinate.latitude,
                        location.coordinate.longitude
                    )
                }
            } else {
                self.locationName = String(
                    format: "%.4f, %.4f",
                    location.coordinate.latitude,
                    location.coordinate.longitude
                )
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isLoading = false
    }
}

// MARK: - Post Preview View

struct PostPreviewView: View {
    let image: UIImage
    let onDiscard: () -> Void
    let onPost: () -> Void

    @State private var caption = ""
    @State private var captureDate = Date()
    @State private var scope: PostScope = .friends
    @State private var locationManager = PostLocationManager()
    @FocusState private var captionFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    imagePreviewSection
                    captionSection
                    dateTimeSection
                    locationSection
                    scopeSection
                    postButton
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .ignoresSafeArea(edges: .top)
            .navigationTitle("New Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Discard") {
                        onDiscard()
                    }
                    .foregroundStyle(.red)
                }
            }
        }
        .onAppear {
            locationManager.requestLocation()
        }
    }

    // MARK: - Subviews

    private var imagePreviewSection: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity)
            .clipped()
    }

    private var captionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Caption", systemImage: "text.bubble")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            TextField("Write a caption…", text: $caption, axis: .vertical)
                .lineLimit(3...6)
                .padding(12)
                .background(
                    .ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: 10)
                )
                .focused($captionFocused)
        }
        .padding(.horizontal, 16)
    }

    private var dateTimeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Date & Time", systemImage: "calendar.badge.clock")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Image(systemName: "clock.fill")
                    .foregroundStyle(.blue)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(dateString)
                        .font(.subheadline.weight(.medium))
                    Text(timeString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(12)
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: 10)
            )
        }
        .padding(.horizontal, 16)
    }

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Location", systemImage: "location.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                locationContent
                Spacer()
            }
            .padding(12)
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: 10)
            )
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var locationContent: some View {
        if locationManager.isLoading {
            ProgressView()
                .controlSize(.small)
            Text("Getting location…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else if let name = locationManager.locationName {
            Image(systemName: "mappin.circle.fill")
                .foregroundStyle(.red)
                .font(.title3)
            Text(name)
                .font(.subheadline)
        } else {
            Image(systemName: "location.slash.fill")
                .foregroundStyle(.secondary)
                .font(.title3)
            Text("Location unavailable")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var scopeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Who can see this?", systemImage: "eye")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 0) {
                ForEach(PostScope.allCases) { option in
                    ScopeOptionButton(
                        option: option,
                        isSelected: scope == option
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            scope = option
                        }
                    }
                }
            }
            .padding(4)
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: 12)
            )
        }
        .padding(.horizontal, 16)
    }

    private var postButton: some View {
        Button {
            onPost()
        } label: {
            Text("Post")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .tint(.blue)
        .padding(.horizontal, 16)
        .padding(.bottom, 32)
    }

    // MARK: - Helpers

    private var dateString: String {
        captureDate.formatted(
            .dateTime.weekday(.wide).month(.wide).day().year()
        )
    }

    private var timeString: String {
        captureDate.formatted(
            .dateTime.hour().minute().second()
        )
    }
}

// MARK: - Scope Option Button

struct ScopeOptionButton: View {
    let option: PostScope
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: option.icon)
                    .font(.title3)
                Text(option.rawValue)
                    .font(.caption.weight(.semibold))
                Text(option.subtitle)
                    .font(.caption2)
                    .foregroundStyle(
                        isSelected ? Color.blue.opacity(0.8) : Color.gray.opacity(0.4)
                    )
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                isSelected ? Color.blue.opacity(0.12) : Color.clear,
                in: RoundedRectangle(cornerRadius: 10)
            )
            .foregroundStyle(isSelected ? .blue : .secondary)
        }
        .buttonStyle(.plain)
    }
}
