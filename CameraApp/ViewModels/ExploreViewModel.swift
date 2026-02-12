import CoreLocation
import MapKit
import Observation
import SwiftUI

// MARK: - Explore View Model

@Observable
final class ExploreViewModel {
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

                // Build a nice location name from the map item
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

    func loadPendingMoment(store: MomentsStore) {
        guard let moment = store.pendingMoment else { return }
        selectedDate = moment.date
        pinnedCoordinate = moment.coordinate
        locationName = moment.locationName
        showDatePicker = false
        showMap = false
        momentSaved = false

        // Center the map on the moment's location
        cameraPosition = .region(
            MKCoordinateRegion(
                center: moment.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
        )

        store.pendingMoment = nil
        performSearch()
    }

    // MARK: - Search

    func performSearch() {
        guard let coord = pinnedCoordinate else { return }
        isSearching = true
        hasSearched = false
        momentSaved = false

        // Collapse all expanded UI elements
        withAnimation(.spring(duration: 0.3)) {
            showDatePicker = false
            showMap = false
        }
        dismissPlaceSearch()

        // Simulate network delay
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1200))
            withAnimation(.spring(duration: 0.4)) {
                posts = ImagePost.samplePosts(near: coord, around: selectedDate)
                hasSearched = true
                isSearching = false
            }
        }
    }
}
