import Foundation

/// GeoJSON Point representation for PostGIS geography columns.
/// Referenced by the generated Supabase types but not included in codegen output.
struct GeographySelect: Codable, Hashable, Sendable {
    let type: String
    let coordinates: [Double]

    /// GeoJSON uses [longitude, latitude] ordering.
    var latitude: Double {
        coordinates[1]
    }
    var longitude: Double {
        coordinates[0]
    }

    static func point(latitude: Double, longitude: Double) -> Self {
        Self(type: "Point", coordinates: [longitude, latitude])
    }
}
