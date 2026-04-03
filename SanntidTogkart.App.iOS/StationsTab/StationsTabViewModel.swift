import CoreLocation
import Foundation
import Observation

@MainActor
@Observable
final class StationsTabViewModel {
    var stations: [TraseStation] = []
    var filteredStations: [TraseStation] = []
    var errorMessage: String?
    var isLoading = false
    var searchText = ""
    var currentLocation: CLLocation?

    var locationAuthorizationStatus: CLAuthorizationStatus {
        locationManager.authorizationStatus
    }

    private let service: SignalRService
    private let locationManager: StationListLocationManager
    private var hasStarted = false

    init() {
        self.service = SignalRService()
        self.locationManager = StationListLocationManager()
        configureBindings()
    }

    init(service: SignalRService) {
        self.service = service
        self.locationManager = StationListLocationManager()
        configureBindings()
    }

    private func configureBindings() {
        locationManager.onLocationUpdate = { [weak self] location in
            guard let self else {
                return
            }

            self.currentLocation = location
        }

        service.onStations = { [weak self] stations in
            guard let self else {
                return
            }

            self.stations = stations
            self.applySearch()
            self.errorMessage = nil
            self.isLoading = false
        }

        service.onError = { [weak self] message in
            guard let self else {
                return
            }

            self.errorMessage = message
            self.isLoading = false
        }
    }

    func start() async {
        guard !hasStarted else {
            return
        }

        hasStarted = true
        isLoading = true
        locationManager.start()
        await service.start()
        await service.requestStations()
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil
        await service.requestStations(forceRefresh: true)
    }

    func updateSearchText(_ text: String) {
        searchText = text
        applySearch()
    }

    func requestLocationAccess() {
        locationManager.start()
    }

    func stop() {
        hasStarted = false
        locationManager.stop()
        service.stop()
    }

    func distanceText(for station: TraseStation) -> String? {
        guard
            let currentLocation,
            let latitude = station.latitude,
            let longitude = station.longitude
        else {
            return nil
        }

        let stationLocation = CLLocation(latitude: latitude, longitude: longitude)
        let distance = currentLocation.distance(from: stationLocation)

        if distance < 1000 {
            return "\(Int(distance.rounded())) m"
        }

        return String(format: "%.1f km", distance / 1000)
    }

    private func applySearch() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty else {
            filteredStations = stations
            return
        }

        filteredStations = stations.filter { station in
            station.name.localizedCaseInsensitiveContains(query)
                || station.shortName.localizedCaseInsensitiveContains(query)
                || station.countryCode.localizedCaseInsensitiveContains(query)
                || (station.plcCode?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }
}

@MainActor
private final class StationListLocationManager: NSObject, CLLocationManagerDelegate {
    var onLocationUpdate: ((CLLocation) -> Void)?

    var authorizationStatus: CLAuthorizationStatus {
        manager.authorizationStatus
    }

    private let manager: CLLocationManager

    override init() {
        let manager = CLLocationManager()
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 100
        self.manager = manager
        super.init()
        manager.delegate = self
    }

    func start() {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.startUpdatingLocation()
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        default:
            break
        }
    }

    func stop() {
        manager.stopUpdatingLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.startUpdatingLocation()
        default:
            manager.stopUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            return
        }

        onLocationUpdate?(location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        manager.stopUpdatingLocation()
    }
}
