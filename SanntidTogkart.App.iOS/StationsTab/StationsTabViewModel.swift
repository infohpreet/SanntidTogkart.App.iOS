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

    private let service: SignalRService
    private var hasStarted = false

    init() {
        self.service = SignalRService()
        configureBindings()
    }

    init(service: SignalRService) {
        self.service = service
        configureBindings()
    }

    private func configureBindings() {
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

    func stop() {
        hasStarted = false
        service.stop()
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
