import Foundation
import Supabase
import SwiftUI

// MARK: - Codable Row (decodes user_badges table response)

struct PostBadgeRow: Codable {
    let id: UUID
    let badgeType: String
    let metadata: AnyJSON

    enum CodingKeys: String, CodingKey {
        case id
        case badgeType = "badge_type"
        case metadata
    }

    func toPostBadge() -> PostBadge? {
        guard case let .object(dict) = metadata,
              case let .string(name) = dict["badge_name"],
              case let .string(description) = dict["badge_description"]
        else { return nil }

        return PostBadge(
            id: id,
            badgeType: badgeType,
            badgeName: name,
            badgeDescription: description
        )
    }
}

// MARK: - Display Model

struct PostBadge: Identifiable {
    let id: UUID
    let badgeType: String
    let badgeName: String
    let badgeDescription: String

    var displayIcon: String {
        Self.icon(forType: badgeType)
    }

    var displayColor: Color {
        Self.color(forType: badgeType)
    }

    static func icon(forType badgeType: String) -> String {
        switch badgeType {
        case "first_post": "star.fill"
        case "location_discoverer": "mappin.and.ellipse"
        case "first_among_friends": "person.2.fill"
        default: "medal.fill"
        }
    }

    static func color(forType badgeType: String) -> Color {
        switch badgeType {
        case "first_post": .yellow
        case "location_discoverer": .teal
        case "first_among_friends": .purple
        default: .secondary
        }
    }
}

// MARK: - AnyJSON String Extraction

extension AnyJSON {
    func stringValue(forKey key: String) -> String? {
        guard case let .object(dict) = self,
              case let .string(value) = dict[key]
        else { return nil }
        return value
    }
}
