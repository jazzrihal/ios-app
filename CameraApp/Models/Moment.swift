import CoreLocation
import Foundation

struct Moment: Identifiable {
    let id = UUID()
    let date: Date
    let locationName: String
    let coordinate: CLLocationCoordinate2D
    let addedAt: Date

    // MARK: - Formatted helpers

    var dateFormatted: String {
        date.formatted(.dateTime.month(.abbreviated).day().year().hour().minute())
    }

    var timeFormatted: String {
        date.formatted(.dateTime.hour().minute())
    }

    var addedAtFormatted: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: addedAt, relativeTo: .now)
    }
}

// MARK: - Sample Data

extension Moment {
    static func sampleMoments() -> [Moment] {
        let now = Date()
        return [
            Moment(
                date: Calendar.current.date(byAdding: .hour, value: -3, to: now)!,
                locationName: "San Francisco, United States",
                coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                addedAt: Calendar.current.date(byAdding: .minute, value: -15, to: now)!
            ),
            Moment(
                date: Calendar.current.date(byAdding: .hour, value: -18, to: now)!,
                locationName: "Los Angeles, United States",
                coordinate: CLLocationCoordinate2D(latitude: 34.0522, longitude: -118.2437),
                addedAt: Calendar.current.date(byAdding: .hour, value: -2, to: now)!
            ),
            Moment(
                date: Calendar.current.date(byAdding: .day, value: -3, to: now)!,
                locationName: "New York, United States",
                coordinate: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),
                addedAt: Calendar.current.date(byAdding: .day, value: -1, to: now)!
            ),
            Moment(
                date: Calendar.current.date(byAdding: .day, value: -7, to: now)!,
                locationName: "London, United Kingdom",
                coordinate: CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278),
                addedAt: Calendar.current.date(byAdding: .day, value: -3, to: now)!
            ),
            Moment(
                date: Calendar.current.date(byAdding: .day, value: -14, to: now)!,
                locationName: "Tokyo, Japan",
                coordinate: CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.6503),
                addedAt: Calendar.current.date(byAdding: .day, value: -5, to: now)!
            ),
        ]
    }
}
