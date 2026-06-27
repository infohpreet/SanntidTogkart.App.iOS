import Foundation
import Observation

enum DashboardTab: String, CaseIterable, Identifiable, Hashable {
    case map
    case trains
    case home
    case routes
    case stations
    case settings

    var id: Self {
        self
    }

    static let startupTabs: [DashboardTab] = [.home, .trains, .map]

    var title: String {
        switch self {
        case .map:
            return "Kart"
        case .trains:
            return "Søk"
        case .home:
            return "Hjem"
        case .routes:
            return "Ruter"
        case .stations:
            return "Stasjoner"
        case .settings:
            return "Mer"
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
    let countryCode: String
    let trainNo: String
    let advertisementTrainNo: String
    let originDate: String
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
    var trainMapSelectionTrainMessage: TrainMessage?

    private init() {
        let storedRawValue = UserDefaults.standard.string(forKey: Self.startupDashboardTabKey)
        let storedTab = storedRawValue.flatMap(DashboardTab.init(rawValue:))
        selectedDashboardTab = DashboardTab.startupTabs.contains(storedTab ?? .home) ? (storedTab ?? .home) : .home
    }

    func showStationOnMap(_ station: TraseStation) {
        selectedDashboardTab = .map
        trainMapSelectionRequest = nil
        trainMapSelectionTrainMessage = nil
        stationMapSelectionRequest = StationMapSelectionRequest(
            stationID: station.id,
            latitude: station.latitude,
            longitude: station.longitude
        )
    }

    func showTrainOnMap(_ trainMessage: TrainMessage) {
        selectedDashboardTab = .map
        stationMapSelectionRequest = nil
        trainMapSelectionTrainMessage = trainMessage
        trainMapSelectionRequest = TrainMapSelectionRequest(
            trainMessageID: trainMessage.id,
            countryCode: trainMessage.countryCode,
            trainNo: trainMessage.trainNo,
            advertisementTrainNo: trainMessage.advertisementTrainNo,
            originDate: trainMessage.originDate
        )
    }

    func resetToMap() {
        selectedDashboardTab = .map
        stationMapSelectionRequest = nil
        trainMapSelectionRequest = nil
        trainMapSelectionTrainMessage = nil
    }
}
