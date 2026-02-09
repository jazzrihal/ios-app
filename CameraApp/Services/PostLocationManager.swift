import CoreLocation

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
