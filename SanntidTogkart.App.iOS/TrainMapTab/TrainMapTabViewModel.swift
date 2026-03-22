import Foundation
import MapKit
import Observation
import SwiftUI

@MainActor
@Observable
final class TrainMapTabViewModel {
    var stations: [TraseStation] = []
    var trainMessages: [TrainMessage] = []
    var selectedTrainMessageID: Int?
    var selectedTrainRouteCoordinates: [CLLocationCoordinate2D] = []
    var errorMessage: String?
    var isLoading = false

    var mappableStations: [TraseStation] {
        stations.filter { $0.latitude != nil && $0.longitude != nil }
    }

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

    var selectedTrain: TrainMessage? {
        guard let selectedTrainMessageID else {
            return nil
        }

        return trainMessages.first(where: { $0.id == selectedTrainMessageID })
    }

    private func configureBindings() {
        service.onStations = { [weak self] stations in
            guard let self else {
                return
            }

            self.stations = stations
            self.errorMessage = nil
            self.isLoading = false
        }

        service.onLiveTrainMessages = { [weak self] trainMessages in
            guard let self else {
                return
            }

            let activeTrainMessages = trainMessages
                .filter { self.isActiveTrainMessage($0) && self.mapCoordinate(for: $0) != nil }
                .sorted { lhs, rhs in
                    self.displayLineNumber(for: lhs).localizedStandardCompare(self.displayLineNumber(for: rhs)) == .orderedAscending
                }

            withAnimation(.easeInOut(duration: 0.35)) {
                self.trainMessages = activeTrainMessages
            }

            if let selectedTrainMessageID = self.selectedTrainMessageID,
               !activeTrainMessages.contains(where: { $0.id == selectedTrainMessageID }) {
                self.clearSelection()
            } else {
                self.updateSelectedTrainRouteWithLatestPosition()
            }

            self.errorMessage = nil
        }

        service.onTrainRoutePositions = { [weak self] trainPositions in
            guard let self else {
                return
            }

            let routeCoordinates = trainPositions
                .sorted { lhs, rhs in
                    lhs.geoJson.properties.serviceTime < rhs.geoJson.properties.serviceTime
                }
                .compactMap(self.coordinate(for:))

            self.selectedTrainRouteCoordinates = routeCoordinates.removingSequentialDuplicates()
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

    func stop() {
        hasStarted = false
        service.stop()
    }

    func displayRoute(for trainMessage: TrainMessage) -> String {
        let origin = displayStationText(for: trainMessage.origin, countryCode: trainMessage.countryCode)
        let destination = displayStationText(for: trainMessage.destination, countryCode: trainMessage.countryCode)

        switch (origin, destination) {
        case let (.some(origin), .some(destination)):
            return "\(origin) → \(destination)"
        case let (.some(origin), _):
            return origin
        case let (_, .some(destination)):
            return destination
        default:
            return "Rute oppdateres"
        }
    }

    func stationsInVisibleRegion(_ region: MKCoordinateRegion, limit: Int) -> [TraseStation] {
        Array(
            mappableStations
                .filter { station in
                    region.contains(latitude: station.latitude, longitude: station.longitude)
                }
                .prefix(limit)
        )
    }

    func trainsInVisibleRegion(_ region: MKCoordinateRegion, limit: Int) -> [TrainMessage] {
        Array(
            trainMessages
                .filter { trainMessage in
                    guard let coordinate = mapCoordinate(for: trainMessage) else {
                        return false
                    }

                    return region.contains(latitude: coordinate.latitude, longitude: coordinate.longitude)
                }
                .prefix(limit)
        )
    }

    func selectTrain(_ trainMessage: TrainMessage) async {
        selectedTrainMessageID = trainMessage.id
        selectedTrainRouteCoordinates = []

        guard
            let countryCode = normalizedText(trainMessage.countryCode),
            let trainNumber = routeTrainNumber(for: trainMessage),
            let originDate = routeOriginDate(for: trainMessage)
        else {
            return
        }

        await service.requestTrainPositionsList(
            countryCode: countryCode,
            trainNumber: trainNumber,
            originDate: originDate
        )
    }

    func clearSelection() {
        selectedTrainMessageID = nil
        selectedTrainRouteCoordinates = []
    }

    func mapCoordinate(for trainMessage: TrainMessage) -> CLLocationCoordinate2D? {
        coordinate(for: trainMessage.trainPosition)
    }

    func displayCountryCode(for trainMessage: TrainMessage) -> String {
        normalizedText(trainMessage.countryCode) ?? "Ukjent land"
    }

    func displayTrainNumber(for trainMessage: TrainMessage) -> String {
        normalizedText(trainMessage.trainNo)
            ?? normalizedText(trainMessage.advertisementTrainNo)
            ?? normalizedText(trainMessage.trainPosition?.geoJson.properties.trainNumber)
            ?? "Tog"
    }

    func displayLineNumber(for trainMessage: TrainMessage) -> String {
        let trainNumber = displayTrainNumber(for: trainMessage)

        guard let lineNumber = normalizedText(trainMessage.lineNumber) else {
            return trainNumber
        }

        return "\(lineNumber) • \(trainNumber)"
    }

    func displayCompany(for trainMessage: TrainMessage) -> String {
        normalizedText(trainMessage.company)
            ?? normalizedText(trainMessage.trainPosition?.toc)
            ?? normalizedText(trainMessage.trainPosition?.geoJson.properties.operatorRef)
            ?? "Operatør mangler"
    }

    func displayCoordinateText(for trainMessage: TrainMessage) -> String {
        guard let coordinate = mapCoordinate(for: trainMessage) else {
            return "Ukjent"
        }

        return String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude)
    }

    func searchTokens(for trainMessage: TrainMessage) -> [String] {
        [
            displayLineNumber(for: trainMessage),
            displayTrainNumber(for: trainMessage),
            trainMessage.origin,
            trainMessage.destination,
            trainMessage.lineNumber,
            trainMessage.trainType,
            trainMessage.company,
            trainMessage.countryCode
        ]
        .compactMap { normalizedText($0) }
    }

    private func updateSelectedTrainRouteWithLatestPosition() {
        guard
            let selectedTrain,
            let latestCoordinate = mapCoordinate(for: selectedTrain)
        else {
            return
        }

        if selectedTrainRouteCoordinates.isEmpty {
            selectedTrainRouteCoordinates = [latestCoordinate]
            return
        }

        if selectedTrainRouteCoordinates.count == 1 {
            if !selectedTrainRouteCoordinates[0].isApproximatelyEqual(to: latestCoordinate) {
                selectedTrainRouteCoordinates.append(latestCoordinate)
            }
            return
        }

        if selectedTrainRouteCoordinates[selectedTrainRouteCoordinates.count - 2].isApproximatelyEqual(to: latestCoordinate) {
            selectedTrainRouteCoordinates.removeLast()
            return
        }

        if !selectedTrainRouteCoordinates.last!.isApproximatelyEqual(to: latestCoordinate) {
            selectedTrainRouteCoordinates[selectedTrainRouteCoordinates.count - 1] = latestCoordinate
        }
    }

    private func coordinate(for trainPosition: TrainPosition?) -> CLLocationCoordinate2D? {
        guard
            let trainPosition,
            trainPosition.geoJson.geometry.coordinates.count >= 2
        else {
            return nil
        }

        return CLLocationCoordinate2D(
            latitude: trainPosition.geoJson.geometry.coordinates[1],
            longitude: trainPosition.geoJson.geometry.coordinates[0]
        )
    }

    private func routeTrainNumber(for trainMessage: TrainMessage) -> String? {
        normalizedText(trainMessage.trainNo)
            ?? normalizedText(trainMessage.advertisementTrainNo)
            ?? normalizedText(trainMessage.trainPosition?.geoJson.properties.trainNumber)
    }

    private func routeOriginDate(for trainMessage: TrainMessage) -> String? {
        normalizedText(trainMessage.originDate)
            ?? normalizedText(trainMessage.trainPosition?.geoJson.properties.originDate)
    }

    private func isActiveTrainMessage(_ trainMessage: TrainMessage) -> Bool {
        guard let serviceTime = trainMessage.trainPosition?.geoJson.properties.serviceTime else {
            return false
        }

        return serviceTime >= Date().addingTimeInterval(-activeTrainTimeout)
    }

    private func normalizedText(_ value: String?) -> String? {
        let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return normalized.isEmpty ? nil : normalized
    }

    private func displayStationText(for rawValue: String?, countryCode: String) -> String? {
        let normalized = normalizedText(rawValue)

        guard let normalized else {
            return nil
        }

        if let station = stations.first(where: { station in
            station.countryCode.localizedCaseInsensitiveCompare(countryCode) == .orderedSame
                && (
                    station.shortName.localizedCaseInsensitiveCompare(normalized) == .orderedSame
                || station.name.localizedCaseInsensitiveCompare(normalized) == .orderedSame
                || (station.plcCode?.localizedCaseInsensitiveCompare(normalized) == .orderedSame)
                )
        }) {
            return station.name
        }

        return normalized
    }
}

private extension MKCoordinateRegion {
    func contains(latitude: Double?, longitude: Double?) -> Bool {
        guard let latitude, let longitude else {
            return false
        }

        let minLatitude = center.latitude - (span.latitudeDelta / 2)
        let maxLatitude = center.latitude + (span.latitudeDelta / 2)
        let minLongitude = center.longitude - (span.longitudeDelta / 2)
        let maxLongitude = center.longitude + (span.longitudeDelta / 2)

        return latitude >= minLatitude
            && latitude <= maxLatitude
            && longitude >= minLongitude
            && longitude <= maxLongitude
    }
}

private extension Array where Element == CLLocationCoordinate2D {
    func removingSequentialDuplicates() -> [CLLocationCoordinate2D] {
        reduce(into: []) { result, coordinate in
            if let last = result.last, last.isApproximatelyEqual(to: coordinate) {
                return
            }
            result.append(coordinate)
        }
    }
}

private extension CLLocationCoordinate2D {
    func isApproximatelyEqual(to other: CLLocationCoordinate2D) -> Bool {
        abs(latitude - other.latitude) < 0.00001 && abs(longitude - other.longitude) < 0.00001
    }
}

private let activeTrainTimeout: TimeInterval = 5 * 60
