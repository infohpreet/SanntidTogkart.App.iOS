import Foundation
import Observation

enum DashboardTab: Hashable {
    case map
    case favorites
    case routes
    case stations
    case settings
}

struct StationMapSelectionRequest: Equatable {
    let stationID: UUID
    let latitude: Double?
    let longitude: Double?
    let requestID = UUID()
}

@MainActor
@Observable
final class AppNavigationCenter {
    static let shared = AppNavigationCenter()

    var selectedDashboardTab: DashboardTab = .map
    var stationMapSelectionRequest: StationMapSelectionRequest?

    private init() {}

    func showStationOnMap(_ station: TraseStation) {
        selectedDashboardTab = .map
        stationMapSelectionRequest = StationMapSelectionRequest(
            stationID: station.id,
            latitude: station.latitude,
            longitude: station.longitude
        )
    }
}
