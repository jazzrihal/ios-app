import CoreLocation
import MapKit
import Observation
import SwiftUI

// MARK: - Explore View Model

@Observable
final class ExploreViewModel: NSObject, CLLocationManagerDelegate, TabRefreshable {
    // MARK: - Search Parameters

    var selectedDate = Date()
    var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    )
    var pinnedCoordinate: CLLocationCoordinate2D?
    var locationName: String?
    var isReverseGeocoding = false

    // MARK: - Results

    var posts: [ImagePost] = []
    var hasSearched = false
    var isSearching = false
    /// True only during a user-initiated pull-to-refresh. Center overlays must not
    /// appear while this is true — the native pull spinner is the only indicator.
    var isRefreshing = false
    var isLoadingMore = false
    var hasMorePages = true
    var searchError: String?

    private let pageSize = 20

    // MARK: - UI Toggles

    var showDatePicker = false
    var showMap = false
    var momentSaved = false

    // MARK: - Place Search

    var searchCompleter = LocationSearchCompleter()
    var isResolvingPlace = false

    // MARK: - Navigation State

    var navigateToProfileUser: User?
    var navigateToPostIndex: Int?

    // MARK: - Current Location

    private let locationManager = CLLocationManager()
    private var hasLoadedInitialLocation = false
    var isFetchingLocation = false

    // MARK: - Repository

    var postRepository: (any PostRepository)?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    /// Requests the user's current location and uses it for the first explore query.
    /// Only runs once; skips if a pending moment already set a coordinate.
    /// Uses the cached location from CLLocationManager when available (fresh within 10 min)
    /// to eliminate the loading state in the common case.
    func fetchCurrentLocationOnLaunch() {
        guard !hasLoadedInitialLocation else { return }
        hasLoadedInitialLocation = true

        guard pinnedCoordinate == nil else { return }

        let status = locationManager.authorizationStatus
        guard status == .authorizedWhenInUse || status == .authorizedAlways else {
            if status == .notDetermined {
                isFetchingLocation = true
                locationManager.requestWhenInUseAuthorization()
            }
            return
        }

        if let cached = locationManager.location,
           cached.timestamp.timeIntervalSinceNow > -600 {
            let coord = cached.coordinate
            withAnimation(.spring(duration: 0.3)) {
                pinnedCoordinate = coord
                cameraPosition = .region(
                    MKCoordinateRegion(
                        center: coord,
                        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                    )
                )
            }
            reverseGeocode(coord)
            Task { await performSearch() }
        } else {
            isFetchingLocation = true
            locationManager.requestLocation()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard isFetchingLocation else { return }
        let status = manager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.requestLocation()
        } else if status != .notDetermined {
            isFetchingLocation = false
        }
    }

    func locationManager(
        _ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]
    ) {
        guard isFetchingLocation else { return }
        isFetchingLocation = false
        guard let location = locations.first else { return }

        guard pinnedCoordinate == nil else { return }

        let coord = location.coordinate

        withAnimation(.spring(duration: 0.3)) {
            pinnedCoordinate = coord
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: coord,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                )
            )
        }

        reverseGeocode(coord)
        Task { await performSearch() }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError _: Error) {
        isFetchingLocation = false
    }

    // MARK: - Date Shortcuts

    enum DateShortcut: String, CaseIterable, Identifiable {
        case today = "Today"
        case yesterday = "Yesterday"
        case oneWeekAgo = "1 week ago"
        case oneMonthAgo = "1 month ago"
        case oneYearAgo = "1 year ago"

        var id: String {
            rawValue
        }

        var date: Date {
            let calendar = Calendar.current
            let now = Date()
            switch self {
            case .today:
                return now
            case .yesterday:
                return calendar.date(byAdding: .day, value: -1, to: now)!
            case .oneWeekAgo:
                return calendar.date(byAdding: .weekOfYear, value: -1, to: now)!
            case .oneMonthAgo:
                return calendar.date(byAdding: .month, value: -1, to: now)!
            case .oneYearAgo:
                return calendar.date(byAdding: .year, value: -1, to: now)!
            }
        }
    }

    func applyDateShortcut(_ shortcut: DateShortcut) {
        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            selectedDate = shortcut.date
        }
    }

    // MARK: - Date/Map Toggle Actions

    func toggleDatePicker() {
        withAnimation(.spring(duration: 0.3)) {
            showDatePicker.toggle()
            showMap = false
        }
    }

    func toggleMap() {
        withAnimation(.spring(duration: 0.3)) {
            showMap.toggle()
            showDatePicker = false
        }
    }

    // MARK: - Place Search Actions

    func selectPlace(_ completion: MKLocalSearchCompletion) {
        isResolvingPlace = true

        Task { @MainActor in
            if let mapItem = await searchCompleter.resolve(completion) {
                let coord = mapItem.placemark.coordinate

                withAnimation(.spring(duration: 0.3)) {
                    pinnedCoordinate = coord
                    cameraPosition = .region(
                        MKCoordinateRegion(
                            center: coord,
                            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                        )
                    )
                }

                let placemark = mapItem.placemark
                let city = placemark.locality
                let country = placemark.country
                let name = mapItem.name

                if let name, let city, let country {
                    locationName = "\(name), \(city), \(country)"
                } else if let city, let country {
                    locationName = "\(city), \(country)"
                } else if let name {
                    locationName = name
                } else {
                    reverseGeocode(coord)
                }
            }

            isResolvingPlace = false
            searchCompleter.queryFragment = ""
        }
    }

    func dismissPlaceSearch() {
        searchCompleter.queryFragment = ""
    }

    func handleMapTap(coordinate coord: CLLocationCoordinate2D) {
        withAnimation(.spring(duration: 0.3)) {
            pinnedCoordinate = coord
        }
        reverseGeocode(coord)
        dismissPlaceSearch()
    }

    // MARK: - Reverse Geocoding

    func reverseGeocode(_ coordinate: CLLocationCoordinate2D) {
        isReverseGeocoding = true
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let coordinateFallback = String(
            format: "%.4f, %.4f",
            coordinate.latitude,
            coordinate.longitude
        )

        geocoder.reverseGeocodeLocation(location) { [self] placemarks, _ in
            isReverseGeocoding = false

            guard let placemark = placemarks?.first else {
                locationName = coordinateFallback
                return
            }

            let city = placemark.locality
            let country = placemark.country
            switch (city, country) {
            case let (city?, country?):
                locationName = "\(city), \(country)"
            case let (nil, country?):
                locationName = country
            case let (city?, nil):
                locationName = city
            default:
                locationName = coordinateFallback
            }
        }
    }

    // MARK: - Moment Actions

    @MainActor
    func saveMoment(store: MomentsStore) {
        guard let coord = pinnedCoordinate, let name = locationName else { return }
        store.addMoment(date: selectedDate, locationName: name, coordinate: coord)

        withAnimation {
            momentSaved = true
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            withAnimation {
                momentSaved = false
            }
        }
    }

    @MainActor
    func loadPendingMoment(store: MomentsStore) {
        guard let moment = store.pendingMoment else { return }
        selectedDate = moment.date
        pinnedCoordinate = moment.coordinate
        locationName = moment.locationName
        showDatePicker = false
        showMap = false
        momentSaved = false

        cameraPosition = .region(
            MKCoordinateRegion(
                center: moment.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
        )

        store.pendingMoment = nil
        Task { await performSearch() }
    }

    // MARK: - Search

    @MainActor
    func performSearch() async {
        guard let coord = pinnedCoordinate else { return }
        isSearching = true
        momentSaved = false
        searchError = nil
        hasMorePages = true

        withAnimation(.spring(duration: 0.3)) {
            showDatePicker = false
            showMap = false
        }
        dismissPlaceSearch()

        do {
            var params = NearbyPostsParams(
                lng: coord.longitude,
                lat: coord.latitude,
                searchDate: Self.iso8601String(from: selectedDate),
                radiusMeters: 5000
            )
            params.pageSize = pageSize
            params.pageOffset = 0

            let result: [ImagePost]
            if let repo = postRepository {
                result = try await repo.nearbyPosts(params: params)
            } else {
                let rows: [NearbyPostRow] = try await SupabaseManager.client
                    .rpc("nearby_posts", params: params)
                    .execute()
                    .value
                result = rows.map { ImagePost(from: $0) }
            }

            withAnimation(.spring(duration: 0.4)) {
                posts = result
                hasSearched = true
                isSearching = false
                hasMorePages = result.count == pageSize
            }
        } catch {
            withAnimation(.spring(duration: 0.4)) {
                searchError = AuthManager.userFacingServiceErrorMessage(for: error)
                hasSearched = true
                isSearching = false
            }
        }
    }

    // MARK: - TabRefreshable

    /// True while the first location-based search is in-flight (no results yet).
    var isInitialLoading: Bool {
        !hasSearched && isSearching
    }

    /// Surfaces the most recent search error for the refresh contract.
    var lastRefreshError: String? {
        searchError
    }

    func refresh() async {
        await refreshSearch()
    }

    /// Forces a fresh first page by invalidating nearby-post cache before searching.
    /// Guards against overlapping concurrent refresh operations.
    @MainActor
    func refreshSearch() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        postRepository?.invalidateNearbyPosts()
        await performSearch()
    }

    @MainActor
    func loadNextPage() async {
        guard hasMorePages, !isLoadingMore, let coord = pinnedCoordinate else { return }

        isLoadingMore = true

        do {
            var params = NearbyPostsParams(
                lng: coord.longitude,
                lat: coord.latitude,
                searchDate: Self.iso8601String(from: selectedDate),
                radiusMeters: 5000
            )
            params.pageSize = pageSize
            params.pageOffset = posts.count

            let newPosts: [ImagePost]
            if let repo = postRepository {
                newPosts = try await repo.nearbyPostsNextPage(params: params)
            } else {
                let rows: [NearbyPostRow] = try await SupabaseManager.client
                    .rpc("nearby_posts", params: params)
                    .execute()
                    .value
                newPosts = rows.map { ImagePost(from: $0) }
            }

            posts.append(contentsOf: newPosts)
            hasMorePages = newPosts.count == pageSize
        } catch {
            searchError = AuthManager.userFacingServiceErrorMessage(for: error)
        }

        isLoadingMore = false
    }

    private static func iso8601String(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
