import CoreLocation
import Observation
import SwiftUI

struct HomeTabView: View {
    @State private var favoritesStore = TrainStationFavoritesStore.shared
    @State private var lastUsedStore = TrainStationLastUsedStore.shared
    @State private var isTrainListPresented = false
    @State private var isTrainRoutePresented = false
    @State private var selectedStation: TraseStation?
    @State private var selectedStationMessage: StationMessage?
    @State private var selectedTrainMessage: TrainMessage?
    @State private var activeSwipeStationID: UUID?
    @State private var viewModel = HomeTabViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if favoritesStore.stations.isEmpty {
                    ContentUnavailableView(
                        "Ingen favoritter",
                        systemImage: "star",
                        description: Text("Legg til stasjoner som favoritter fra stasjonslisten for å se dem her.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            favoriteSection

                            if let nearestStation = viewModel.nearestStation {
                                nearestSection(nearestStation)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 12)
                        .appReadableContentWidth()
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle(tabGreetingTitle)
            .navigationDestination(isPresented: $isTrainListPresented) {
                if let selectedStation {
                    TrainListView(station: selectedStation)
                }
            }
            .navigationDestination(isPresented: $isTrainRoutePresented) {
                if let selectedStation, let selectedStationMessage {
                    TrainRouteView(
                        station: selectedStation,
                        stationMessage: selectedStationMessage,
                        trainMessage: selectedTrainMessage,
                        direction: .departure
                    )
                }
            }
        }
        .task {
            await viewModel.start()
        }
        .onChange(of: favoritesStore.stations.map(\.storageKey)) { _, _ in
            viewModel.refreshNearestStation()
        }
    }

    private var tabGreetingTitle: String {
        let hour = Calendar.autoupdatingCurrent.component(.hour, from: AppTime.now)

        switch hour {
        case 5..<12:
            return "God morgen!"
        case 12..<18:
            return "God ettermiddag!"
        default:
            return "God kveld!"
        }
    }

    private var favoriteSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "Favoritter")
            favoriteBoards(favoritesStore.stations)
        }
    }

    private func nearestSection(_ station: TraseStation) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "Nærmeste")

            HomeFavoriteStationBoard(
                station: station,
                distanceText: viewModel.distanceText(for: station),
                onSelectStation: {
                    selectStation(station)
                },
                onSelectTrain: { stationMessage, trainMessage in
                    selectTrainRoute(for: station, stationMessage: stationMessage, trainMessage: trainMessage)
                }
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func favoriteBoards(_ stations: [TraseStation]) -> some View {
        VStack(spacing: 14) {
            ForEach(stations) { station in
                SwipeDeleteIconRow(
                    rowID: station.id,
                    activeRowID: $activeSwipeStationID,
                    onDelete: {
                        favoritesStore.remove(station)
                    }
                ) {
                    favoriteBoard(station)
                }
            }
        }
    }

    private func sectionHeader(title: String) -> some View {
        HStack {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func favoriteBoard(_ station: TraseStation) -> some View {
        HomeFavoriteStationBoard(
            station: station,
            distanceText: viewModel.distanceText(for: station),
            onSelectStation: {
                selectStation(station)
            },
            onSelectTrain: { stationMessage, trainMessage in
                selectTrainRoute(for: station, stationMessage: stationMessage, trainMessage: trainMessage)
            }
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func selectStation(_ station: TraseStation) {
        activeSwipeStationID = nil
        lastUsedStore.record(station)
        selectedStation = station
        isTrainListPresented = true
    }

    private func selectTrainRoute(for station: TraseStation, stationMessage: StationMessage, trainMessage: TrainMessage?) {
        activeSwipeStationID = nil
        lastUsedStore.record(station)
        selectedStation = station
        selectedStationMessage = stationMessage
        selectedTrainMessage = trainMessage
        isTrainRoutePresented = true
    }
}

private struct SwipeDeleteIconRow<Content: View>: View {
    let rowID: UUID
    @Binding var activeRowID: UUID?
    let onDelete: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var offsetX: CGFloat = 0
    @State private var rowHeight: CGFloat = 56

    private var revealWidth: CGFloat {
        max(44, rowHeight)
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            deleteButton

            content()
                .contentShape(Rectangle())
                .offset(x: offsetX)
                .background {
                    GeometryReader { proxy in
                        Color.clear
                            .onAppear {
                                rowHeight = proxy.size.height
                            }
                            .onChange(of: proxy.size.height) { _, newHeight in
                                rowHeight = newHeight
                            }
                    }
                }
                .simultaneousGesture(dragGesture)
                .animation(.spring(response: 0.23, dampingFraction: 0.86), value: offsetX)
        }
            .frame(maxWidth: .infinity, alignment: .leading)
        .clipped()
        .onChange(of: activeRowID) { _, newValue in
            closeIfInactive(newValue)
        }
    }

    private var deleteButton: some View {
        HStack {
            Spacer(minLength: 0)

            Button(role: .destructive) {
                activeRowID = nil
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: revealWidth, height: rowHeight)
                    .background(Color.red)
            }
            .buttonStyle(.plain)
            .opacity(offsetX <= -8 ? 1 : 0)
            .allowsHitTesting(offsetX <= -8)
        }
        .frame(width: revealWidth)
        .frame(height: rowHeight)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 16)
            .onChanged { value in
                guard abs(value.translation.width) > abs(value.translation.height) else {
                    return
                }

                if value.translation.width < 0, activeRowID != rowID {
                    activeRowID = rowID
                    offsetX = 0
                }

                offsetX = max(-revealWidth, min(0, value.translation.width))
            }
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else {
                    offsetX = 0
                    return
                }

                let shouldReveal = value.translation.width < -24 || value.predictedEndTranslation.width < -46
                if shouldReveal {
                    activeRowID = rowID
                    offsetX = -revealWidth
                } else {
                    activeRowID = nil
                    offsetX = 0
                }
            }
    }

    private func closeIfInactive(_ activeID: UUID?) {
        guard activeID == rowID else {
            offsetX = 0
            return
        }
    }
}

@MainActor
@Observable
private final class HomeTabViewModel {
    private(set) var currentLocation: CLLocation?
    private(set) var nearestStation: TraseStation?

    private let service: SignalRService
    private let locationManager: HomeTabLocationManager
    private var stations: [TraseStation] = []
    private var hasStarted = false

    init() {
        self.service = SignalRService()
        self.locationManager = HomeTabLocationManager()
        configureBindings()
    }

    private func configureBindings() {
        locationManager.onLocationUpdate = { [weak self] location in
            guard let self else {
                return
            }

            self.currentLocation = location
            self.updateNearestStation()
        }

        service.onStations = { [weak self] stations in
            guard let self else {
                return
            }

            self.stations = stations.sorted {
                $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
            self.updateNearestStation()
        }
    }

    func start() async {
        guard !hasStarted else {
            return
        }

        hasStarted = true
        locationManager.start()
        await service.start()
        await service.requestStations()
    }

    func refreshNearestStation() {
        updateNearestStation()
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

    private func updateNearestStation() {
        guard let currentLocation else {
            nearestStation = nil
            return
        }

        let favoriteStationKeys = Set(TrainStationFavoritesStore.shared.stations.map(\.storageKey))

        nearestStation = stations
            .compactMap { station -> (station: TraseStation, distance: CLLocationDistance)? in
                guard let latitude = station.latitude, let longitude = station.longitude else {
                    return nil
                }

                guard !favoriteStationKeys.contains(station.storageKey) else {
                    return nil
                }

                let stationLocation = CLLocation(latitude: latitude, longitude: longitude)
                return (station, currentLocation.distance(from: stationLocation))
            }
            .sorted { lhs, rhs in
                if lhs.distance == rhs.distance {
                    return lhs.station.name.localizedStandardCompare(rhs.station.name) == .orderedAscending
                }

                return lhs.distance < rhs.distance
            }
            .first?
            .station
    }
}

private struct HomeFavoriteStationBoard: View {
    let station: TraseStation
    let distanceText: String?
    let onSelectStation: () -> Void
    let onSelectTrain: (StationMessage, TrainMessage?) -> Void

    @State private var viewModel = HomeFavoriteStationBoardViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            stationHeader
            Rectangle()
                .fill(HomeFavoriteBoardStyle.divider)
                .frame(height: 1)
                .padding(.horizontal, -16)

            Group {
                if viewModel.isLoading && previewMessages.isEmpty {
                    ProgressView("Laster avganger...")
                        .frame(maxWidth: .infinity, minHeight: 120)
                } else if let errorMessage = viewModel.errorMessage, previewMessages.isEmpty {
                    ContentUnavailableView(
                        "Kunne ikke hente avganger",
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )
                    .frame(maxWidth: .infinity, minHeight: 120)
                } else if previewMessages.isEmpty {
                    ContentUnavailableView(
                        "Ingen avganger",
                        systemImage: "arrow.up.right",
                        description: Text("Ingen avganger ble funnet for denne stasjonen.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 120)
                } else {
                    departureBoard
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        }
        .task(id: station.storageKey) {
            await viewModel.start(for: station)
        }
    }

    private var previewMessages: [StationMessage] {
        Array(viewModel.departureMessages.prefix(3))
    }

    private var stationHeader: some View {
        Button(action: onSelectStation) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(station.name)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .layoutPriority(1)

                    if let distanceText {
                        Text(distanceText)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var departureBoard: some View {
        VStack(spacing: 0) {
            trainRouteButton(for: previewMessages[0]) {
                departureHero(for: previewMessages[0])
            }

            if previewMessages.count > 1 {
                boardHeader

                ForEach(Array(previewMessages.dropFirst().enumerated()), id: \.element.id) { index, stationMessage in
                    trainRouteButton(for: stationMessage) {
                        boardRow(stationMessage)
                    }

                    if index < previewMessages.count - 2 {
                        Rectangle()
                            .fill(HomeFavoriteBoardStyle.divider)
                            .frame(height: 1)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HomeFavoriteBoardStyle.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func trainRouteButton<Content: View>(for stationMessage: StationMessage, @ViewBuilder content: () -> Content) -> some View {
        Button {
            onSelectTrain(stationMessage, viewModel.trainDetail(for: stationMessage))
        } label: {
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func departureHero(for stationMessage: StationMessage) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 12) {
                trainBadge(for: stationMessage, size: .large)

                Spacer(minLength: 12)

                if let trackText = viewModel.trackText(for: stationMessage) {
                    Text("Spor \(trackText)")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(viewModel.isPrimaryTrackActivity(for: stationMessage) ? .primary : .secondary)
                        .lineLimit(1)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Text(viewModel.destinationText(for: stationMessage))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(viewModel.scheduledTimeText(for: stationMessage))
                        .font(.title3.monospacedDigit().weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    if let expectedTimeText = viewModel.expectedTimeDisplayText(for: stationMessage),
                       expectedTimeText != viewModel.scheduledTimeText(for: stationMessage) {
                        Text(expectedTimeText)
                            .font(.subheadline.monospacedDigit().weight(.semibold))
                            .foregroundStyle(HomeFavoriteBoardStyle.delayYellow)
                            .lineLimit(1)

                        Text("Forventet")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(HomeFavoriteBoardStyle.delayYellow)
                    }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 14)
    }

    private var boardHeader: some View {
        VStack(spacing: 10) {
            Rectangle()
                .fill(HomeFavoriteBoardStyle.divider)
                .frame(height: 1)

            HStack(spacing: 10) {
                Text("Avgang")
                    .frame(width: 56, alignment: .leading)

                Text("Tog til")
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("Spor")
                    .frame(width: 30, alignment: .trailing)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(HomeFavoriteBoardStyle.mutedText)
            .padding(.horizontal, 18)
        }
        .padding(.bottom, 6)
    }

    private func boardRow(_ stationMessage: StationMessage) -> some View {
        HStack(alignment: .center, spacing: 10) {
            timeColumn(for: stationMessage)
                .frame(width: 56, alignment: .leading)

            HStack(spacing: 8) {
                trainBadge(for: stationMessage, size: .small)

                Text(viewModel.destinationText(for: stationMessage))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .layoutPriority(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(viewModel.trackText(for: stationMessage) ?? "")
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .foregroundStyle(viewModel.isPrimaryTrackActivity(for: stationMessage) ? .primary : .secondary)
                .frame(width: 30, alignment: .trailing)
                .lineLimit(1)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
    }

    @ViewBuilder
    private func timeColumn(for stationMessage: StationMessage) -> some View {
        let scheduledText = viewModel.scheduledTimeText(for: stationMessage)
        let expectedText = viewModel.expectedTimeDisplayText(for: stationMessage)

        if let expectedText, expectedText != scheduledText {
            VStack(alignment: .leading, spacing: 2) {
                Text(expectedText)
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .foregroundStyle(HomeFavoriteBoardStyle.delayYellow)

                Text(scheduledText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(HomeFavoriteBoardStyle.secondaryText)
                    .strikethrough(true, color: HomeFavoriteBoardStyle.secondaryText)
            }
        } else {
            Text(scheduledText)
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .foregroundStyle(.primary)
        }
    }

    private func trainBadge(for stationMessage: StationMessage, size: HomeFavoriteBadgeSize) -> some View {
        Text(viewModel.trainDisplayText(for: stationMessage))
            .font(size.font)
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(width: size.width, height: size.height)
            .background(
                viewModel.isFreightTrain(for: stationMessage) ? HomeFavoriteBoardStyle.freightGreen : HomeFavoriteBoardStyle.trainRed,
                in: RoundedRectangle(cornerRadius: 1)
            )
    }
}

private enum HomeFavoriteBadgeSize {
    case small
    case large

    var font: Font {
        switch self {
        case .small:
            return .subheadline.monospacedDigit().weight(.bold)
        case .large:
            return .title3.monospacedDigit().weight(.bold)
        }
    }

    var height: CGFloat {
        switch self {
        case .small:
            return 26
        case .large:
            return 34
        }
    }

    var width: CGFloat {
        switch self {
        case .small:
            return 58
        case .large:
            return 76
        }
    }
}

private enum HomeFavoriteBoardStyle {
    static let background = AppTheme.surface
    static let divider = AppTheme.border
    static let mutedText = Color.secondary
    static let secondaryText = Color.secondary
    static let delayYellow = Color(red: 0.86, green: 0.62, blue: 0.0)
    static let freightGreen = Color(red: 0.17, green: 0.52, blue: 0.29)
    static let trainRed = Color(red: 0.90, green: 0.06, blue: 0.12)
}

@MainActor
@Observable
private final class HomeFavoriteStationBoardViewModel {
    private(set) var stationMessages: [StationMessage] = []
    private var trainMessagesByKey: [String: TrainMessage] = [:]
    private var stations: [TraseStation] = []
    var errorMessage: String?
    var isLoading = false

    private let service: SignalRService
    private var requestedStationKey: String?
    private var hasStarted = false

    init() {
        self.service = SignalRService()
        configureBindings()
    }

    var departureMessages: [StationMessage] {
        stationMessages
            .filter(isDepartureVisible)
            .sorted { lhs, rhs in
                let lhsDate = departureSortDate(for: lhs) ?? .distantFuture
                let rhsDate = departureSortDate(for: rhs) ?? .distantFuture

                if lhsDate == rhsDate {
                    return lhs.trainNo.localizedStandardCompare(rhs.trainNo) == .orderedAscending
                }

                return lhsDate < rhsDate
            }
    }

    private func configureBindings() {
        service.onStations = { [weak self] stations in
            self?.stations = stations
        }

        service.onStationMessages = { [weak self] stationMessages in
            guard let self,
                  self.matchesRequestedStation(stationMessages) else {
                return
            }

            self.stationMessages = stationMessages
            self.requestTrainDetails(for: stationMessages)
            self.errorMessage = nil
            self.isLoading = false
        }

        service.onTrainMessage = { [weak self] trainMessage in
            guard let self else {
                return
            }

            self.trainMessagesByKey[self.trainMessageKey(for: trainMessage)] = trainMessage
        }

        service.onError = { [weak self] message in
            guard let self else {
                return
            }

            self.errorMessage = message
            self.isLoading = false
        }
    }

    func start(for station: TraseStation) async {
        if hasStarted, requestedStationKey == station.storageKey {
            return
        }

        hasStarted = true
        await loadStationMessages(for: station)
    }

    func trainDisplayText(for stationMessage: StationMessage) -> String {
        normalizedText(trainDetail(for: stationMessage)?.lineNumber)
            ?? normalizedText(stationMessage.trainNo)
            ?? "-"
    }

    func destinationText(for stationMessage: StationMessage) -> String {
        let rawStationName = normalizedText(trainDetail(for: stationMessage)?.destination)
            ?? normalizedText(stationMessage.city)

        guard let rawStationName else {
            return "Ukjent"
        }

        return displayStationName(for: rawStationName, countryCode: stationMessage.countryCode)
    }

    func trackText(for stationMessage: StationMessage) -> String? {
        normalizedText(stationMessage.scheduledTrack)
    }

    func isPrimaryTrackActivity(for stationMessage: StationMessage) -> Bool {
        normalizedText(stationMessage.activity)?.uppercased() == "S"
    }

    func isFreightTrain(for stationMessage: StationMessage) -> Bool {
        CommonService.isFreightTrainType(trainDetail(for: stationMessage)?.trainType)
    }

    func expectedTimeDisplayText(for stationMessage: StationMessage) -> String? {
        let expectedText = expectedTimeText(for: stationMessage)
        return expectedText.isEmpty ? nil : expectedText
    }

    func scheduledTimeText(for stationMessage: StationMessage) -> String {
        stationMessage.std.map { AppTime.localTimeString(from: $0) } ?? "--:--"
    }

    private func expectedTimeText(for stationMessage: StationMessage) -> String {
        if let expectedDate = stationMessage.etd ?? stationMessage.atd {
            return AppTime.localTimeString(from: expectedDate)
        }

        return ""
    }

    private func loadStationMessages(for station: TraseStation) async {
        let stationShortName = station.shortName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !stationShortName.isEmpty else {
            stationMessages = []
            errorMessage = "Mangler stasjonskode."
            isLoading = false
            return
        }

        requestedStationKey = station.storageKey
        isLoading = true
        errorMessage = nil
        trainMessagesByKey = [:]

        await service.start()
        await service.requestStations()
        await service.requestStationMessages(
            countryCode: station.countryCode,
            stationShortName: stationShortName,
            originDate: AppTime.localDateString()
        )
    }

    private func matchesRequestedStation(_ stationMessages: [StationMessage]) -> Bool {
        guard let requestedStationKey, let firstMessage = stationMessages.first else {
            return false
        }

        let responseKey = "\(firstMessage.countryCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased())::\(firstMessage.city.trimmingCharacters(in: .whitespacesAndNewlines).uppercased())"
        if responseKey == requestedStationKey {
            return true
        }

        return stations.first(where: { $0.storageKey == requestedStationKey })?.shortName.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() == firstMessage.city.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private func requestTrainDetails(for stationMessages: [StationMessage]) {
        for stationMessage in stationMessages.prefix(3) {
            Task {
                await service.requestTrainMessage(
                    countryCode: stationMessage.countryCode,
                    trainNo: stationMessage.trainNo,
                    originDate: stationMessage.originDate
                )
            }
        }
    }

    func trainDetail(for stationMessage: StationMessage) -> TrainMessage? {
        trainMessagesByKey[trainMessageKey(countryCode: stationMessage.countryCode, trainNo: stationMessage.trainNo, originDate: stationMessage.originDate)]
    }

    private func trainMessageKey(for trainMessage: TrainMessage) -> String {
        trainMessageKey(countryCode: trainMessage.countryCode, trainNo: trainMessage.trainNo, originDate: trainMessage.originDate)
    }

    private func trainMessageKey(countryCode: String, trainNo: String, originDate: String) -> String {
        "\(countryCode)-\(trainNo)-\(originDate)"
    }

    private func isDepartureVisible(_ stationMessage: StationMessage) -> Bool {
        guard stationMessage.atd == nil else {
            return false
        }

        return isScheduledTimeVisible(stationMessage.std)
            && (stationMessage.std != nil || stationMessage.etd != nil)
    }

    private func isScheduledTimeVisible(_ scheduledTime: Date?) -> Bool {
        guard let scheduledTime else {
            return true
        }

        return scheduledTime >= AppTime.now.addingTimeInterval(-5 * 60)
    }

    private func departureSortDate(for stationMessage: StationMessage) -> Date? {
        stationMessage.etd ?? stationMessage.std ?? stationMessage.atd
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

@MainActor
private final class HomeTabLocationManager: NSObject, CLLocationManagerDelegate {
    var onLocationUpdate: ((CLLocation) -> Void)?

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

private struct HomeTabDropdownNorwayFlagBadge: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color(red: 0.73, green: 0.11, blue: 0.17))

            Rectangle()
                .fill(.white)
                .frame(width: 7)
                .offset(x: -7)

            Rectangle()
                .fill(.white)
                .frame(height: 7)

            Rectangle()
                .fill(Color(red: 0.0, green: 0.13, blue: 0.36))
                .frame(width: 4)
                .offset(x: -7)

            Rectangle()
                .fill(Color(red: 0.0, green: 0.13, blue: 0.36))
                .frame(height: 4)
        }
        .frame(width: 42, height: 28)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}

private struct HomeTabDropdownSwedenFlagBadge: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color(red: 0.0, green: 0.32, blue: 0.61))

            Rectangle()
                .fill(Color(red: 0.98, green: 0.80, blue: 0.17))
                .frame(width: 6)
                .offset(x: -7)

            Rectangle()
                .fill(Color(red: 0.98, green: 0.80, blue: 0.17))
                .frame(height: 6)
        }
        .frame(width: 42, height: 28)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}
