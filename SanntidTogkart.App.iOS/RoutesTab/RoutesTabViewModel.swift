import Foundation
import Observation

@MainActor
@Observable
final class RoutesTabViewModel {
    var messages: [RouteMessage] = []
    var filteredMessages: [RouteMessage] = []
    var errorMessage: String?
    var isLoading = false
    var searchText = ""

    private let service: SignalRService
    private var hasStarted = false
    private var rawMessages: [TrainMessage] = []
    private var stations: [TraseStation] = []
    private var hasRequestedStations = false

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
            self.publishMessagesIfReady()
        }

        service.onTrainMessages = { [weak self] messages in
            guard let self else {
                return
            }

            self.rawMessages = messages
            if self.stations.isEmpty {
                self.requestStationsIfNeeded(forceRefresh: false)
                return
            }

            self.publishMessagesIfReady()
            self.errorMessage = nil
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
        requestStationsIfNeeded(forceRefresh: false)
        await service.requestTrainMessages(filter: "", originDate: Date())
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil
        requestStationsIfNeeded(forceRefresh: true)
        await service.requestTrainMessages(filter: "", originDate: Date(), forceRefresh: true)
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
            filteredMessages = messages
            return
        }

        filteredMessages = messages.filter { message in
            message.advertisementTrainNo.localizedCaseInsensitiveContains(query)
                || (message.origin?.localizedCaseInsensitiveContains(query) ?? false)
                || (message.destination?.localizedCaseInsensitiveContains(query) ?? false)
                || (message.trainType?.localizedCaseInsensitiveContains(query) ?? false)
                || (message.lineNumber?.localizedCaseInsensitiveContains(query) ?? false)
                || (message.company?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    private func requestStationsIfNeeded(forceRefresh: Bool) {
        guard forceRefresh || !hasRequestedStations else {
            return
        }

        hasRequestedStations = true
        Task { [weak self] in
            guard let self else {
                return
            }

            await self.service.requestStations(forceRefresh: forceRefresh)
        }
    }

    private func publishMessagesIfReady() {
        guard !rawMessages.isEmpty else {
            messages = []
            filteredMessages = []
            isLoading = false
            errorMessage = nil
            return
        }

        guard !stations.isEmpty else {
            isLoading = true
            return
        }

        let stationNames = makeStationNameLookup(from: stations)
        messages = rawMessages.map { message in
            RouteMessage(
                trainMessage: message,
                origin: resolvedStationName(for: message.origin, countryCode: message.countryCode, using: stationNames),
                destination: resolvedStationName(for: message.destination, countryCode: message.countryCode, using: stationNames)
            )
        }
        applySearch()
        errorMessage = nil
        isLoading = false
    }

    private func makeStationNameLookup(from stations: [TraseStation]) -> [String: String] {
        var lookup: [String: String] = [:]

        for station in stations {
            let name = station.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else {
                continue
            }

            let keys = [
                station.shortName,
                station.name,
                station.plcCode
            ]

            for key in keys {
                let normalizedKey = key?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
                guard !normalizedKey.isEmpty else {
                    continue
                }

                let countryCode = station.countryCode.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                lookup["\(countryCode)|\(normalizedKey)"] = name
            }
        }

        return lookup
    }

    private func resolvedStationName(for rawValue: String?, countryCode: String, using stationNames: [String: String]) -> String? {
        let normalized = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !normalized.isEmpty else {
            return nil
        }

        let normalizedCountryCode = countryCode.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let stationName = stationNames["\(normalizedCountryCode)|\(normalized.lowercased())"] {
            return stationName
        }

        return normalized
    }
}

struct RouteMessage: Identifiable {
    let trainMessage: TrainMessage
    let origin: String?
    let destination: String?

    var id: Int { trainMessage.id }
    var countryCode: String { trainMessage.countryCode }
    var advertisementTrainNo: String { trainMessage.advertisementTrainNo }
    var trainNo: String { trainMessage.trainNo }
    var originDate: String { trainMessage.originDate }
    var originTime: Date? { trainMessage.originTime }
    var trainType: String? { trainMessage.trainType }
    var lineNumber: String? { trainMessage.lineNumber }
    var company: String? { trainMessage.company }
}
