import CoreLocation
import Foundation
import Observation

@Observable
class MomentsStore {
    var moments: [Moment] = Moment.sampleMoments()
    var pendingMoment: Moment?
    var selectedTab: Int = 0

    func addMoment(date: Date, locationName: String, coordinate: CLLocationCoordinate2D) {
        let moment = Moment(
            date: date,
            locationName: locationName,
            coordinate: coordinate,
            addedAt: Date()
        )
        moments.append(moment)
    }
}
