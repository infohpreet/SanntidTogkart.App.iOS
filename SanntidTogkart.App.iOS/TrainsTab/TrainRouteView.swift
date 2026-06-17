import Observation
import SwiftUI

struct TrainRouteView: View {
    let station: TraseStation?
    let stationMessage: StationMessage?
    let trainMessage: TrainMessage?
    let direction: TrainRouteDirection

    @State private var viewModel: TrainRouteViewModel

    init(
        station: TraseStation,
        stationMessage: StationMessage,
        trainMessage: TrainMessage?,
        direction: TrainRouteDirection
    ) {
        self.station = station
        self.stationMessage = stationMessage
        self.trainMessage = trainMessage
        self.direction = direction
        _viewModel = State(initialValue: TrainRouteViewModel(initialTrainMessage: trainMessage))
    }

    init(trainMessage: TrainMessage) {
        self.station = nil
        self.stationMessage = nil
        self.trainMessage = trainMessage
        self.direction = .departure
        _viewModel = State(initialValue: TrainRouteViewModel(initialTrainMessage: trainMessage))
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.stationMessages.isEmpty {
                ProgressView("Laster togrute...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = viewModel.errorMessage, viewModel.stationMessages.isEmpty {
                ContentUnavailableView(
                    "Kunne ikke hente togrute",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )
            } else if viewModel.stationMessages.isEmpty {
                ContentUnavailableView(
                    "Ingen togrute",
                    systemImage: "tram.fill.tunnel",
                    description: Text("Ingen stasjoner ble returnert for dette toget.")
                )
            } else {
                ScrollView {
                    routeBoard
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .appReadableContentWidth()
                }
                .scrollIndicators(.hidden)
                .refreshable {
                    await refreshRoute()
                }
            }
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Til \(viewModel.routeDestinationText(fallbackTitle: routeTitleFallback))")
        .task {
            await startRoute()
        }
    }

    private var routeTitleFallback: String {
        if let station {
            return station.name
        }

        if let trainMessage,
           let destinationText = viewModel.destinationText(for: trainMessage) {
            return destinationText
        }

        return "Togrute"
    }

    private func startRoute() async {
        if let stationMessage {
            await viewModel.start(for: stationMessage)
        } else if let trainMessage {
            await viewModel.start(for: trainMessage)
        }
    }

    private func refreshRoute() async {
        if let stationMessage {
            await viewModel.refresh(for: stationMessage)
        } else if let trainMessage {
            await viewModel.refresh(for: trainMessage)
        }
    }

    private var routeBoard: some View {
        VStack(spacing: 0) {
            routeHero

            boardHeader

            ForEach(Array(viewModel.stationMessages.enumerated()), id: \.element.id) { index, message in
                routeRow(message, index: index)
            }
        }
        .background(TrainRouteStyle.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private var routeHero: some View {
        if let heroStationMessage = viewModel.nextRouteStationMessage ?? stationMessage ?? viewModel.stationMessages.first {
            VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 12) {
                trainBadge

                Spacer(minLength: 12)

                if let trackText = viewModel.trackText(for: heroStationMessage) {
                    Text("Spor \(trackText)")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Text(viewModel.stationName(for: heroStationMessage))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.64)

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(viewModel.primaryTimeText(for: heroStationMessage, direction: direction))
                        .font(.title3.monospacedDigit().weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    if let expectedTimeText = viewModel.expectedTimeText(for: heroStationMessage, direction: direction) {
                        Text(expectedTimeText)
                            .font(.subheadline.monospacedDigit().weight(.semibold))
                            .foregroundStyle(TrainRouteStyle.delayYellow)
                            .lineLimit(1)

                        Text("Forventet")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(TrainRouteStyle.delayYellow)
                    }
                }
            }

            if let viaText = viewModel.viaText() {
                Text(viaText)
                    .font(.subheadline)
                    .foregroundStyle(TrainRouteStyle.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 24)
        .padding(.bottom, 18)
        }
    }

    private var boardHeader: some View {
        VStack(spacing: 10) {
            Rectangle()
                .fill(TrainRouteStyle.divider)
                .frame(height: 1)

            HStack(spacing: 10) {
                Text(direction.timeColumnTitle)
                    .frame(width: 56, alignment: .leading)

                Text("Stopp")
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("Spor")
                    .frame(width: 30, alignment: .trailing)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(TrainRouteStyle.mutedText)
            .padding(.horizontal, 18)
        }
        .padding(.bottom, 6)
    }

    private func routeRow(_ message: StationMessage, index: Int) -> some View {
        HStack(alignment: .center, spacing: 10) {
            timeColumn(for: message, index: index)
                .frame(width: 56, alignment: .leading)

            timelineMarker(for: index, totalCount: viewModel.stationMessages.count)
                .frame(width: 32, height: 56)

            Text(viewModel.stationName(for: message))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(viewModel.trackText(for: message) ?? "")
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .foregroundStyle(.primary)
                .frame(width: 30, alignment: .trailing)
                .lineLimit(1)
        }
        .padding(.horizontal, 18)
        .frame(height: 56)
    }

    @ViewBuilder
    private func timeColumn(for message: StationMessage, index: Int) -> some View {
        let scheduledText = viewModel.scheduledTimeText(for: message, direction: direction)
        let expectedText = viewModel.expectedTimeText(for: message, direction: direction)

        if let expectedText, expectedText != scheduledText {
            VStack(alignment: .leading, spacing: 2) {
                Text(expectedText)
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .foregroundStyle(TrainRouteStyle.delayYellow)

                Text(scheduledText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(TrainRouteStyle.secondaryText)
                    .strikethrough(true, color: TrainRouteStyle.secondaryText)
            }
        } else {
            Text(scheduledText)
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .foregroundStyle(index <= viewModel.currentRouteIndex ? .primary : TrainRouteStyle.secondaryText)
        }
    }

    private func timelineMarker(for index: Int, totalCount: Int) -> some View {
        let currentIndex = viewModel.currentRouteIndex
        let isCurrent = index == currentIndex
        let isPassed = index < currentIndex
        let isFirst = index == 0
        let isLast = index == totalCount - 1

        return ZStack {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(isFirst ? Color.clear : (index <= currentIndex ? TrainRouteStyle.lineRed : TrainRouteStyle.timelineInactive))

                Rectangle()
                    .fill(isLast ? Color.clear : (index < currentIndex ? TrainRouteStyle.lineRed : TrainRouteStyle.timelineInactive))
            }
            .frame(width: 5)
            .frame(maxHeight: .infinity)

            if isCurrent {
                Circle()
                    .fill(TrainRouteStyle.lineRed)
                    .frame(width: 24, height: 24)
                    .overlay {
                        Circle()
                            .stroke(.white, lineWidth: 4)
                    }
            } else {
                Rectangle()
                    .fill(isPassed ? TrainRouteStyle.lineRed : TrainRouteStyle.timelineInactive)
                    .frame(width: isFirst || isLast ? 22 : 18, height: 5)
                    .offset(x: isFirst || isLast ? 0 : 8)
            }
        }
    }

    private var trainBadge: some View {
        Text(viewModel.lineText(for: stationMessage))
            .font(.title3.monospacedDigit().weight(.bold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(width: 76, height: 34)
            .background(TrainRouteStyle.trainRed, in: RoundedRectangle(cornerRadius: 1))
    }
}

enum TrainRouteDirection {
    case departure
    case arrival

    var titlePrefix: String {
        switch self {
        case .departure:
            return "Fra"
        case .arrival:
            return "Til"
        }
    }

    var timeColumnTitle: String {
        switch self {
        case .departure:
            return "Avgang"
        case .arrival:
            return "Ankomst"
        }
    }
}

private struct TrainRouteTrainIdentity {
    let countryCode: String
    let trainNo: String
    let originDate: String
}

private enum TrainRouteStyle {
    static let background = AppTheme.surface
    static let divider = AppTheme.border
    static let mutedText = Color.secondary
    static let secondaryText = Color.secondary
    static let trainRed = Color(red: 0.90, green: 0.06, blue: 0.12)
    static let lineRed = Color(red: 0.93, green: 0.10, blue: 0.14)
    static let timelineInactive = Color.secondary.opacity(0.34)
    static let delayYellow = Color(red: 0.86, green: 0.62, blue: 0.0)
}

@MainActor
@Observable
private final class TrainRouteViewModel {
    private(set) var stationMessages: [StationMessage] = []
    private(set) var trainMessage: TrainMessage?
    var errorMessage: String?
    var isLoading = false

    private let service: SignalRService
    private var stations: [TraseStation] = []
    private var requestedTrainIdentity: TrainRouteTrainIdentity?
    private var hasStarted = false

    init(initialTrainMessage: TrainMessage?) {
        self.trainMessage = initialTrainMessage
        self.service = SignalRService()
        configureBindings()
    }

    private func configureBindings() {
        service.onStations = { [weak self] stations in
            guard let self else {
                return
            }

            self.stations = stations
        }

        service.onTrainStations = { [weak self] stationMessages in
            guard let self,
                  self.matchesRequestedRoute(stationMessages) else {
                return
            }

            self.stationMessages = stationMessages
            self.errorMessage = nil
            self.isLoading = false
        }

        service.onTrainMessage = { [weak self] trainMessage in
            guard let self,
                  self.matchesRequestedTrain(trainMessage) else {
                return
            }

            self.trainMessage = trainMessage
        }

        service.onError = { [weak self] message in
            guard let self else {
                return
            }

            self.errorMessage = message
            self.isLoading = false
        }
    }

    func start(for stationMessage: StationMessage) async {
        guard !hasStarted else {
            return
        }

        hasStarted = true
        await loadRoute(for: stationMessage)
    }

    func refresh(for stationMessage: StationMessage) async {
        await loadRoute(for: stationMessage)
    }

    func start(for trainMessage: TrainMessage) async {
        guard !hasStarted else {
            return
        }

        hasStarted = true
        await loadRoute(for: trainMessage)
    }

    func refresh(for trainMessage: TrainMessage) async {
        await loadRoute(for: trainMessage)
    }

    func lineText(for stationMessage: StationMessage?) -> String {
        let matchingTrainMessage = trainMessage.flatMap { trainMessage in
            if let stationMessage {
                return matches(trainMessage, stationMessage: stationMessage) ? trainMessage : nil
            }

            return trainMessage
        }

        return normalizedText(matchingTrainMessage?.lineNumber)
            ?? normalizedText(stationMessage?.trainNo)
            ?? normalizedText(matchingTrainMessage?.trainNo)
            ?? normalizedText(matchingTrainMessage?.advertisementTrainNo)
            ?? "-"
    }

    func routeDestinationText(fallbackTitle: String) -> String {
        guard let destinationMessage = stationMessages.last else {
            return fallbackTitle
        }

        return stationName(for: destinationMessage)
    }

    func destinationText(for trainMessage: TrainMessage) -> String? {
        normalizedText(trainMessage.destination)
            .map { displayStationName(for: $0, countryCode: trainMessage.countryCode) }
    }

    var nextRouteStationMessage: StationMessage? {
        guard !stationMessages.isEmpty else {
            return nil
        }

        guard let latestPastRouteIndex else {
            return stationMessages.first
        }

        let nextIndex = min(latestPastRouteIndex + 1, stationMessages.count - 1)
        return stationMessages[nextIndex]
    }

    func stationName(for stationMessage: StationMessage) -> String {
        displayStationName(for: stationMessage.city, countryCode: stationMessage.countryCode)
    }

    func trackText(for stationMessage: StationMessage) -> String? {
        normalizedText(stationMessage.scheduledTrack)
    }

    func primaryTimeText(for stationMessage: StationMessage, direction: TrainRouteDirection) -> String {
        expectedTimeText(for: stationMessage, direction: direction) ?? scheduledTimeText(for: stationMessage, direction: direction)
    }

    func scheduledTimeText(for stationMessage: StationMessage, direction: TrainRouteDirection) -> String {
        let date: Date?
        switch direction {
        case .departure:
            date = stationMessage.std ?? stationMessage.sta
        case .arrival:
            date = stationMessage.sta ?? stationMessage.std
        }

        return date.map { AppTime.localTimeString(from: $0) } ?? "--:--"
    }

    func expectedTimeText(for stationMessage: StationMessage, direction: TrainRouteDirection) -> String? {
        let date: Date?
        switch direction {
        case .departure:
            date = stationMessage.etd ?? stationMessage.eta
        case .arrival:
            date = stationMessage.eta ?? stationMessage.etd
        }

        return date.map { AppTime.localTimeString(from: $0) }
    }

    var currentRouteIndex: Int {
        latestPastRouteIndex ?? 0
    }

    private var latestPastRouteIndex: Int? {
        stationMessages.lastIndex { stationMessage in
            guard let referenceDate = routeReferenceDate(for: stationMessage) else {
                return false
            }

            return referenceDate <= AppTime.now
        }
    }

    func viaText() -> String? {
        let stationNames = selectedViaStationMessages()
            .map { stationName(for: $0) }

        guard !stationNames.isEmpty else {
            return nil
        }

        return "via " + stationNames.joined(separator: " · ")
    }

    private func selectedViaStationMessages() -> [StationMessage] {
        let stopMessages = stationMessages
            .dropFirst()
            .dropLast()
            .filter { stationMessage in
                stationMessage.activity.trimmingCharacters(in: .whitespacesAndNewlines)
                    .localizedCaseInsensitiveCompare("S") == .orderedSame
            }

        guard !stopMessages.isEmpty else {
            return []
        }

        let selectedCount: Int
        switch stopMessages.count {
        case 1...5:
            selectedCount = 1
        case 6...10:
            selectedCount = 2
        default:
            selectedCount = 3
        }

        guard selectedCount < stopMessages.count else {
            return Array(stopMessages)
        }

        var selectedIndexes: [Int] = []
        for position in 1...selectedCount {
            let proportionalIndex = Int((Double(stopMessages.count - 1) * Double(position) / Double(selectedCount + 1)).rounded())
            let clampedIndex = min(max(proportionalIndex, 0), stopMessages.count - 1)

            if !selectedIndexes.contains(clampedIndex) {
                selectedIndexes.append(clampedIndex)
            }
        }

        var fallbackIndex = 0
        while selectedIndexes.count < selectedCount && fallbackIndex < stopMessages.count {
            if !selectedIndexes.contains(fallbackIndex) {
                selectedIndexes.append(fallbackIndex)
            }
            fallbackIndex += 1
        }

        return selectedIndexes
            .sorted()
            .map { stopMessages[stopMessages.index(stopMessages.startIndex, offsetBy: $0)] }
    }

    private func routeReferenceDate(for stationMessage: StationMessage) -> Date? {
        stationMessage.ata
            ?? stationMessage.atd
            ?? stationMessage.eta
            ?? stationMessage.etd
            ?? stationMessage.sta
            ?? stationMessage.std
    }

    private func loadRoute(for stationMessage: StationMessage) async {
        let trainNumber = stationMessage.trainNo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trainNumber.isEmpty else {
            stationMessages = []
            errorMessage = "Mangler tognummer."
            isLoading = false
            return
        }

        await loadRoute(
            countryCode: stationMessage.countryCode,
            trainNumber: trainNumber,
            originDate: stationMessage.originDate,
            shouldFetchTrainMessage: true
        )
    }

    private func loadRoute(for trainMessage: TrainMessage) async {
        let trainNumber = trainMessage.trainNo.trimmingCharacters(in: .whitespacesAndNewlines)
        let advertisementTrainNumber = trainMessage.advertisementTrainNo.trimmingCharacters(in: .whitespacesAndNewlines)
        let requestedTrainNumber = trainNumber.isEmpty ? advertisementTrainNumber : trainNumber

        guard !requestedTrainNumber.isEmpty else {
            stationMessages = []
            errorMessage = "Mangler tognummer."
            isLoading = false
            return
        }

        self.trainMessage = trainMessage
        await loadRoute(
            countryCode: trainMessage.countryCode,
            trainNumber: requestedTrainNumber,
            originDate: trainMessage.originDate,
            shouldFetchTrainMessage: false
        )
    }

    private func loadRoute(
        countryCode: String,
        trainNumber: String,
        originDate: String,
        shouldFetchTrainMessage: Bool
    ) async {
        let identity = TrainRouteTrainIdentity(
            countryCode: countryCode,
            trainNo: trainNumber,
            originDate: originDate
        )
        requestedTrainIdentity = identity
        if let trainMessage, !matches(trainMessage, identity: identity) {
            self.trainMessage = nil
        }

        isLoading = true
        errorMessage = nil

        await service.start()
        await service.requestStations()

        if shouldFetchTrainMessage && self.trainMessage == nil {
            await service.requestTrainMessage(
                countryCode: countryCode,
                trainNo: trainNumber,
                originDate: originDate
            )
        }

        await service.requestTrainStations(
            countryCode: countryCode,
            trainNumber: trainNumber,
            originDate: originDate
        )
    }

    private func matchesRequestedRoute(_ stationMessages: [StationMessage]) -> Bool {
        guard let requestedTrainIdentity else {
            return false
        }

        guard !stationMessages.isEmpty else {
            return true
        }

        return stationMessages.contains { stationMessage in
            stationMessage.countryCode.localizedCaseInsensitiveCompare(requestedTrainIdentity.countryCode) == .orderedSame
                && stationMessage.trainNo.localizedCaseInsensitiveCompare(requestedTrainIdentity.trainNo) == .orderedSame
                && stationMessage.originDate == requestedTrainIdentity.originDate
        }
    }

    private func matchesRequestedTrain(_ trainMessage: TrainMessage) -> Bool {
        guard let requestedTrainIdentity else {
            return false
        }

        return matches(trainMessage, identity: requestedTrainIdentity)
    }

    private func matches(_ trainMessage: TrainMessage, stationMessage: StationMessage) -> Bool {
        matches(
            trainMessage,
            identity: TrainRouteTrainIdentity(
                countryCode: stationMessage.countryCode,
                trainNo: stationMessage.trainNo,
                originDate: stationMessage.originDate
            )
        )
    }

    private func matches(_ trainMessage: TrainMessage, identity: TrainRouteTrainIdentity) -> Bool {
        let trainNumbers = [
            normalizedText(trainMessage.trainNo),
            normalizedText(trainMessage.advertisementTrainNo)
        ].compactMap { $0 }

        return trainMessage.countryCode.localizedCaseInsensitiveCompare(identity.countryCode) == .orderedSame
            && trainNumbers.contains { $0.localizedCaseInsensitiveCompare(identity.trainNo) == .orderedSame }
            && trainMessage.originDate == identity.originDate
    }

    private func displayStationName(for rawValue: String, countryCode: String) -> String {
        let normalizedValue = normalizedText(rawValue) ?? rawValue

        if let station = stations.first(where: { station in
            station.countryCode.localizedCaseInsensitiveCompare(countryCode) == .orderedSame
                && (
                    station.shortName.localizedCaseInsensitiveCompare(normalizedValue) == .orderedSame
                        || station.name.localizedCaseInsensitiveCompare(normalizedValue) == .orderedSame
                        || (station.plcCode?.localizedCaseInsensitiveCompare(normalizedValue) == .orderedSame)
                )
        }) {
            return station.name
        }

        return rawValue
    }

    private func normalizedText(_ value: String?) -> String? {
        let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return normalized.isEmpty ? nil : normalized
    }
}
