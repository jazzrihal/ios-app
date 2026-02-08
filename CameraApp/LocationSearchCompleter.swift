import Combine
import MapKit

/// Wraps MKLocalSearchCompleter to provide real-time place search suggestions.
@Observable
final class LocationSearchCompleter: NSObject, MKLocalSearchCompleterDelegate {
    var queryFragment: String = "" {
        didSet {
            completer.queryFragment = queryFragment
            if queryFragment.isEmpty {
                results = []
                isSearching = false
            }
        }
    }

    private(set) var results: [MKLocalSearchCompletion] = []
    private(set) var isSearching = false

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    // MARK: - MKLocalSearchCompleterDelegate

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        results = completer.results
        isSearching = false
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        results = []
        isSearching = false
    }

    // MARK: - Resolve a completion into a coordinate

    func resolve(_ completion: MKLocalSearchCompletion) async -> MKMapItem? {
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        do {
            let response = try await search.start()
            return response.mapItems.first
        } catch {
            return nil
        }
    }
}
