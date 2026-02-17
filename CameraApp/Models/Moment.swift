import CoreLocation
import Foundation

struct Moment: Identifiable {
    let id: UUID
    let date: Date
    let locationName: String
    let coordinate: CLLocationCoordinate2D
    let addedAt: Date

    /// Memberwise initializer with auto-generated `id`.
    init(
        id: UUID = UUID(),
        date: Date,
        locationName: String,
        coordinate: CLLocationCoordinate2D,
        addedAt: Date
    ) {
        self.id = id
        self.date = date
        self.locationName = locationName
        self.coordinate = coordinate
        self.addedAt = addedAt
    }

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

// MARK: - Init from Supabase

extension Moment {
    /// Creates a `Moment` from a Supabase `MomentsSelect` row.
    init(from row: PublicSchema.MomentsSelect) {
        id = row.id
        date = ISO8601DateFormatter.flexibleParse(row.momentDate) ?? Date()
        locationName = row.locationName ?? ""
        coordinate = CLLocationCoordinate2D(
            latitude: row.latitude,
            longitude: row.longitude
        )
        addedAt = ISO8601DateFormatter.flexibleParse(row.createdAt) ?? Date()
    }
}
