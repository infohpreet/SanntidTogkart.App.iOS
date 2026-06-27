import Foundation
import Observation

enum DashboardTab: String, CaseIterable, Identifiable, Hashable {
    case map
    case trains
    case routes
    case stations
    case settings

    var id: Self {
        self
    }

    static let startupTabs: [DashboardTab] = [.map, .routes, .trains, .stations]

    var title: String {
        switch self {
        case .map:
            return "Kart"
        case .trains:
            return "NÅ"
        case .routes:
            return "Ruter"
        case .stations:
            return "Stasjoner"
        case .settings:
            return "Profil"
        }
    }
}

struct StationMapSelectionRequest: Equatable {
    let stationID: UUID
    let latitude: Double?
    let longitude: Double?
    let requestID = UUID()
}

struct TrainMapSelectionRequest: Equatable {
    let trainMessageID: Int
    let requestID = UUID()
}

@MainActor
@Observable
final class AppNavigationCenter {
    static let startupDashboardTabKey = "startupDashboardTab"
    static let shared = AppNavigationCenter()

    var selectedDashboardTab: DashboardTab
    var stationMapSelectionRequest: StationMapSelectionRequest?
    var trainMapSelectionRequest: TrainMapSelectionRequest?

    private init() {
        let storedRawValue = UserDefaults.standard.string(forKey: Self.startupDashboardTabKey)
        let storedTab = storedRawValue.flatMap(DashboardTab.init(rawValue:))
        selectedDashboardTab = DashboardTab.startupTabs.contains(storedTab ?? .trains) ? (storedTab ?? .trains) : .trains
    }

    func showStationOnMap(_ station: TraseStation) {
        selectedDashboardTab = .map
        trainMapSelectionRequest = nil
        stationMapSelectionRequest = StationMapSelectionRequest(
            stationID: station.id,
            latitude: station.latitude,
            longitude: station.longitude
        )
    }

    func showTrainOnMap(_ trainMessage: TrainMessage) {
        selectedDashboardTab = .map
        stationMapSelectionRequest = nil
        trainMapSelectionRequest = TrainMapSelectionRequest(trainMessageID: trainMessage.id)
    }

    func resetToMap() {
        selectedDashboardTab = .map
        stationMapSelectionRequest = nil
        trainMapSelectionRequest = nil
    }
}
