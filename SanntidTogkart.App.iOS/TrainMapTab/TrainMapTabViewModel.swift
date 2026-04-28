import Foundation
import MapKit
import Observation
import SwiftUI

struct OperatorTrainCount: Identifiable, Hashable {
    let name: String
    let count: Int

    var id: String { name }
}

@MainActor
@Observable
final class TrainMapTabViewModel {
    var stations: [TraseStation] = []
    var trainMessages: [TrainMessage] = []
    var metrics: TrainMetrics?
    var selectedTrainMessageID: Int?
    var selectedTrainRouteCoordinates: [CLLocationCoordinate2D] = []
    var selectedTrainFutureRouteCoordinates: [CLLocationCoordinate2D] = []
    var selectedTrainRemainingDistance: CLLocationDistance?
    var selectedTrainTotalRouteDistance: CLLocationDistance?
    var selectedTrainRouteProgress: Double?
    var selectedTrainPassedDistanceText: String?
    var errorMessage: String?
    var isLoading = false

    var totalLiveTrainCount: Int {
        liveTrainMessages.count
    }

    var operatorCounts: [OperatorTrainCount] {
        Dictionary(grouping: liveTrainMessages) { trainMessage in
            let normalizedCompany = displayCompanyValue(for: trainMessage) ?? "Operatør mangler"
            return normalizedCompany
        }
        .map { OperatorTrainCount(name: $0.key, count: $0.value.count) }
        .sorted { lhs, rhs in
            if lhs.count == rhs.count {
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }

            return lhs.count > rhs.count
        }
    }

    var trainTypeCounts: [OperatorTrainCount] {
        Dictionary(grouping: liveTrainMessages) { trainMessage in
            let trainType = normalizedText(trainMessage.trainType) ?? ""
            return trainType
        }
        .filter { !$0.key.isEmpty }
        .map { OperatorTrainCount(name: $0.key, count: $0.value.count) }
        .sorted { lhs, rhs in
            if lhs.count == rhs.count {
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }

            return lhs.count > rhs.count
        }
    }

    var mappableStations: [TraseStation] {
        stations.filter { $0.latitude != nil && $0.longitude != nil }
    }

    private let service: SignalRService
    private var hasStarted = false
    private var liveTrainMessages: [TrainMessage] = []
    private var selectedTrainStations: [StationMessage] = []
    private var selectedTrainRouteRequest: SelectedTrainRouteRequest?

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
        service.onMetrics = { [weak self] metrics in
            guard let self else {
                return
            }

            self.metrics = metrics
            self.errorMessage = nil
            self.isLoading = false
        }

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

            let activeLiveTrainMessages = trainMessages
                .filter { self.isActiveTrainMessage($0) }
            self.liveTrainMessages = activeLiveTrainMessages

            let activeTrainMessages = trainMessages
                .filter { self.isActiveTrainMessage($0) && self.mapCoordinate(for: $0) != nil }
                .sorted { lhs, rhs in
                    self.displayLineNumber(for: lhs).localizedStandardCompare(self.displayLineNumber(for: rhs)) == .orderedAscending
                }

            self.trainMessages = activeTrainMessages

            if let selectedTrainMessageID = self.selectedTrainMessageID,
               !activeTrainMessages.contains(where: { $0.id == selectedTrainMessageID }) {
                self.clearSelection()
            } else {
                self.updateSelectedTrainRouteWithLatestPosition()
                self.rebuildSelectedTrainFutureRoute()
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

        service.onTrainStations = { [weak self] stationMessages in
            guard let self else {
                return
            }

            guard self.matchesSelectedTrainRouteRequest(stationMessages) else {
                return
            }

            self.selectedTrainStations = stationMessages
            self.rebuildSelectedTrainFutureRoute()
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
        await service.requestTrainMetrics()
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil
        await service.requestStations(forceRefresh: true)
        await service.requestTrainMetrics()
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
        selectedTrainFutureRouteCoordinates = []
        selectedTrainStations = []

        guard
            let countryCode = normalizedText(trainMessage.countryCode),
            let trainNumber = routeTrainNumber(for: trainMessage),
            let originDate = routeOriginDate(for: trainMessage)
        else {
            return
        }

        selectedTrainRouteRequest = SelectedTrainRouteRequest(
            trainMessageID: trainMessage.id,
            countryCode: countryCode,
            trainNumber: trainNumber,
            advertisementTrainNo: normalizedText(trainMessage.advertisementTrainNo),
            originDate: originDate
        )

        await service.requestTrainPositionsList(
            countryCode: countryCode,
            trainNumber: trainNumber,
            originDate: originDate
        )

        await service.requestTrainStations(
            countryCode: countryCode,
            trainNumber: trainNumber,
            originDate: originDate
        )
    }

    func clearSelection() {
        selectedTrainMessageID = nil
        selectedTrainRouteCoordinates = []
        selectedTrainFutureRouteCoordinates = []
        selectedTrainRemainingDistance = nil
        selectedTrainTotalRouteDistance = nil
        selectedTrainRouteProgress = nil
        selectedTrainPassedDistanceText = nil
        selectedTrainStations = []
        selectedTrainRouteRequest = nil
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
        displayCompanyValue(for: trainMessage)
            ?? "Operatør mangler"
    }

    func displayCoordinateText(for trainMessage: TrainMessage) -> String {
        guard let coordinate = mapCoordinate(for: trainMessage) else {
            return "Ukjent"
        }

        return String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude)
    }

    var selectedTrainRemainingDistanceText: String? {
        formattedDistanceText(for: selectedTrainRemainingDistance)
    }

    var selectedTrainTotalRouteDistanceText: String? {
        formattedDistanceText(for: selectedTrainTotalRouteDistance)
    }

    var selectedTrainDepartureTimeText: String? {
        selectedTrainStations
            .lazy
            .compactMap { $0.atd ?? $0.etd ?? $0.std }
            .first
            .map(formattedTimeText(for:))
    }

    var selectedTrainArrivalTimeText: String? {
        selectedTrainStations
            .reversed()
            .lazy
            .compactMap { $0.ata ?? $0.eta ?? $0.sta }
            .first
            .map(formattedTimeText(for:))
    }

    var selectedTrainTravelTimeText: String? {
        guard
            let departureDate = selectedTrainDepartureDate,
            let arrivalDate = selectedTrainArrivalDate,
            arrivalDate >= departureDate
        else {
            return nil
        }

        return formattedDurationText(for: arrivalDate.timeIntervalSince(departureDate))
    }

    var selectedTrainRemainingTimeText: String? {
        guard let arrivalDate = selectedTrainArrivalDate else {
            return nil
        }

        return formattedDurationText(for: max(0, arrivalDate.timeIntervalSince(AppTime.now)))
    }

    func searchTokens(for trainMessage: TrainMessage) -> [String] {
        let originCode = normalizedText(trainMessage.origin)
        let destinationCode = normalizedText(trainMessage.destination)
        let enrichedOrigin = displayStationText(for: trainMessage.origin, countryCode: trainMessage.countryCode)
        let enrichedDestination = displayStationText(for: trainMessage.destination, countryCode: trainMessage.countryCode)
        let routeText = displayRoute(for: trainMessage)
        let originTimeText = trainMessage.originTime.map {
            AppTime.localTimeString(from: $0)
        }

        return [
            displayLineNumber(for: trainMessage),
            displayTrainNumber(for: trainMessage),
            normalizedText(trainMessage.advertisementTrainNo),
            normalizedText(trainMessage.trainNo),
            normalizedText(trainMessage.messageKey),
            normalizedText(trainMessage.originDate),
            originTimeText,
            originCode,
            destinationCode,
            enrichedOrigin,
            enrichedDestination,
            routeText,
            normalizedText(trainMessage.lineNumber),
            normalizedText(trainMessage.trainType),
            normalizedText(trainMessage.company),
            normalizedText(trainMessage.countryCode),
            normalizedText(trainMessage.trainPosition?.toc),
            normalizedText(trainMessage.trainPosition?.geoJson.properties.operatorRef),
            normalizedText(trainMessage.trainPosition?.geoJson.properties.trainNumber)
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

        if selectedTrainRouteCoordinates.last?.isApproximatelyEqual(to: latestCoordinate) != true {
            selectedTrainRouteCoordinates.append(latestCoordinate)
        }
    }

    private func rebuildSelectedTrainFutureRoute() {
        guard let selectedTrain else {
            selectedTrainFutureRouteCoordinates = []
            selectedTrainRemainingDistance = nil
            selectedTrainTotalRouteDistance = nil
            selectedTrainRouteProgress = nil
            selectedTrainPassedDistanceText = nil
            return
        }

        var coordinates: [CLLocationCoordinate2D] = []
        if let currentCoordinate = mapCoordinate(for: selectedTrain) {
            coordinates.append(currentCoordinate)
        }

        let futureCoordinates = selectedTrainStations
            .filter { !$0.shouldSkipForFutureRoute }
            .compactMap { coordinateForStation(named: $0.city, countryCode: $0.countryCode) }

        for coordinate in futureCoordinates {
            appendCoordinate(coordinate, to: &coordinates)
        }

        if let destination = normalizedText(selectedTrain.destination),
           let destinationCoordinate = coordinateForStation(named: destination, countryCode: selectedTrain.countryCode) {
            appendCoordinate(destinationCoordinate, to: &coordinates)
        }

        selectedTrainFutureRouteCoordinates = coordinates.count > 1 ? coordinates : []

        var routeCoordinates = selectedTrainStations.compactMap {
            coordinateForStation(named: $0.city, countryCode: $0.countryCode)
        }

        if let destination = normalizedText(selectedTrain.destination),
           let destinationCoordinate = coordinateForStation(named: destination, countryCode: selectedTrain.countryCode) {
            appendCoordinate(destinationCoordinate, to: &routeCoordinates)
        }

        selectedTrainRemainingDistance = distance(for: selectedTrainFutureRouteCoordinates)
        selectedTrainTotalRouteDistance = distance(for: routeCoordinates.removingSequentialDuplicates())

        if
            let totalDistance = selectedTrainTotalRouteDistance,
            let remainingDistance = selectedTrainRemainingDistance,
            totalDistance > 0
        {
            let traveledDistance = max(0, totalDistance - remainingDistance)
            selectedTrainRouteProgress = min(max(traveledDistance / totalDistance, 0), 1)
            selectedTrainPassedDistanceText = formattedDistanceText(for: traveledDistance)
        } else {
            selectedTrainRouteProgress = nil
            selectedTrainPassedDistanceText = nil
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

    private func coordinateForStation(named rawValue: String, countryCode: String) -> CLLocationCoordinate2D? {
        let normalizedValue = normalizedText(rawValue)

        guard let normalizedValue else {
            return nil
        }

        guard let station = stations.first(where: { station in
            station.countryCode.localizedCaseInsensitiveCompare(countryCode) == .orderedSame
                && (
                    station.shortName.localizedCaseInsensitiveCompare(normalizedValue) == .orderedSame
                        || station.name.localizedCaseInsensitiveCompare(normalizedValue) == .orderedSame
                        || (station.plcCode?.localizedCaseInsensitiveCompare(normalizedValue) == .orderedSame)
                )
        }) else {
            return nil
        }

        guard let latitude = station.latitude, let longitude = station.longitude else {
            return nil
        }

        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
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

        return serviceTime >= AppTime.now.addingTimeInterval(-activeTrainTimeout)
    }

    private func normalizedText(_ value: String?) -> String? {
        let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return normalized.isEmpty ? nil : normalized
    }

    private func displayCompanyValue(for trainMessage: TrainMessage) -> String? {
        normalizedText(trainMessage.company)
            ?? normalizedText(trainMessage.trainPosition?.toc)
            ?? normalizedText(trainMessage.trainPosition?.geoJson.properties.operatorRef)
    }

    private func distance(for coordinates: [CLLocationCoordinate2D]) -> CLLocationDistance? {
        guard coordinates.count > 1 else {
            return nil
        }

        var totalDistance: CLLocationDistance = 0

        for index in 1..<coordinates.count {
            let previousLocation = CLLocation(
                latitude: coordinates[index - 1].latitude,
                longitude: coordinates[index - 1].longitude
            )
            let nextLocation = CLLocation(
                latitude: coordinates[index].latitude,
                longitude: coordinates[index].longitude
            )

            totalDistance += previousLocation.distance(from: nextLocation)
        }

        return totalDistance
    }

    private func formattedDistanceText(for distance: CLLocationDistance?) -> String? {
        guard let distance else {
            return nil
        }

        if distance < 1000 {
            return "\(Int(distance.rounded())) m"
        }

        return String(format: "%.1f km", distance / 1000)
    }

    private func formattedTimeText(for date: Date) -> String {
        AppTime.localTimeString(from: date)
    }

    private var selectedTrainDepartureDate: Date? {
        selectedTrainStations
            .lazy
            .compactMap { $0.atd ?? $0.etd ?? $0.std }
            .first
    }

    private var selectedTrainArrivalDate: Date? {
        selectedTrainStations
            .reversed()
            .lazy
            .compactMap { $0.ata ?? $0.eta ?? $0.sta }
            .first
    }

    private func formattedDurationText(for interval: TimeInterval) -> String {
        let totalMinutes = max(0, Int(interval / 60))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours == 0 {
            return "\(totalMinutes) min"
        }

        if minutes == 0 {
            return "\(hours) t"
        }

        return "\(hours) t \(minutes) min"
    }

    private func appendCoordinate(_ coordinate: CLLocationCoordinate2D, to coordinates: inout [CLLocationCoordinate2D]) {
        guard coordinates.last?.isApproximatelyEqual(to: coordinate) != true else {
            return
        }

        coordinates.append(coordinate)
    }

    private func matchesSelectedTrainRouteRequest(_ stationMessages: [StationMessage]) -> Bool {
        guard let selectedTrainRouteRequest else {
            return false
        }

        guard let firstStationMessage = stationMessages.first else {
            return selectedTrainMessageID == selectedTrainRouteRequest.trainMessageID
        }

        guard
            firstStationMessage.countryCode.localizedCaseInsensitiveCompare(selectedTrainRouteRequest.countryCode) == .orderedSame,
            firstStationMessage.originDate == selectedTrainRouteRequest.originDate
        else {
            return false
        }

        let returnedTrainNo = firstStationMessage.trainNo.trimmingCharacters(in: .whitespacesAndNewlines)
        let requestedTrainNo = selectedTrainRouteRequest.trainNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let advertisementTrainNo = selectedTrainRouteRequest.advertisementTrainNo?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return returnedTrainNo == requestedTrainNo || (!advertisementTrainNo.isEmpty && returnedTrainNo == advertisementTrainNo)
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

private extension StationMessage {
    var shouldSkipForFutureRoute: Bool {
        if ata != nil || atd != nil {
            return true
        }

        guard let relevantTimestamp = prioritizedRouteTimestamp else {
            return false
        }

        return relevantTimestamp < AppTime.now
    }

    var prioritizedRouteTimestamp: Date? {
        eta ?? etd ?? sta ?? std
    }
}

private struct SelectedTrainRouteRequest {
    let trainMessageID: Int
    let countryCode: String
    let trainNumber: String
    let advertisementTrainNo: String?
    let originDate: String
}

private let activeTrainTimeout: TimeInterval = 5 * 60
