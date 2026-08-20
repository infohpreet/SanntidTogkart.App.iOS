import Combine
import Observation
import SwiftUI

struct TrainsTabView: View {
    @State private var viewModel = ActiveTrainsTabViewModel()
    @State private var navigationCenter = AppNavigationCenter.shared
    @State private var searchText = ""

    private let minuteRefreshTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.entries.isEmpty {
                    ProgressView("Laster tog...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        Group {
                            if let errorMessage = viewModel.errorMessage, viewModel.entries.isEmpty {
                                ContentUnavailableView(
                                    "Kunne ikke hente tog",
                                    systemImage: "exclamationmark.triangle",
                                    description: Text(errorMessage)
                                )
                                .frame(maxWidth: .infinity, minHeight: 300)
                            } else if viewModel.filteredEntries.isEmpty {
                                ContentUnavailableView(
                                    viewModel.searchText.isEmpty ? "Ingen tog" : "Ingen treff",
                                    systemImage: viewModel.searchText.isEmpty ? "tram.fill" : "magnifyingglass",
                                    description: Text(
                                        viewModel.searchText.isEmpty
                                        ? "Ingen tog er aktive de neste 10 minuttene."
                                        : "Ingen tog matcher soket ditt."
                                    )
                                )
                                .frame(maxWidth: .infinity, minHeight: 300)
                            } else {
                                LazyVStack(alignment: .leading, spacing: 16) {
                                    activeTrainsBoard
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 16)
                        .appReadableContentWidth()
                    }
                    .scrollIndicators(.hidden)
                    .refreshable {
                        await viewModel.refresh()
                    }
                }
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Tog")
            .searchable(text: $searchText, prompt: "Sok etter tog, linje eller stasjon")
        }
        .task {
            await viewModel.start()
        }
        .onChange(of: searchText) { _, newValue in
            viewModel.updateSearchText(newValue)
        }
        .onReceive(minuteRefreshTimer) { _ in
            guard navigationCenter.selectedDashboardTab == .trains else {
                return
            }

            Task {
                await viewModel.refresh()
            }
        }
    }

    private var activeTrainsBoard: some View {
        let entries = viewModel.filteredEntries

        return LazyVStack(spacing: 0) {
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                Group {
                    if let trainMessage = entry.trainMessage {
                        NavigationLink {
                            TrainRouteView(trainMessage: trainMessage)
                        } label: {
                            activeTrainRow(entry)
                        }
                        .buttonStyle(.plain)
                    } else {
                        activeTrainRow(entry)
                    }
                }

                if index < entries.count - 1 {
                    Rectangle()
                        .fill(ActiveTrainsBoardStyle.divider)
                        .frame(height: 1)
                        .padding(.horizontal, 18)
                }
            }
        }
        .background(ActiveTrainsBoardStyle.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func activeTrainRow(_ entry: ActiveTrainEntry) -> some View {
        HStack(alignment: .center, spacing: 12) {
            timeColumn(for: entry.stationMessage)
                .frame(width: 64, alignment: .leading)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    trainBadge(for: entry)

                    Text(entry.cityName)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Spacer(minLength: 8)

                    if let trackText = trackText(for: entry.stationMessage) {
                        Text(trackText)
                            .font(.subheadline.monospacedDigit().weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 6) {
                    Text(originText(for: entry))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .layoutPriority(1)

                    routeArrow

                    Text(destinationText(for: entry))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .layoutPriority(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var routeArrow: some View {
        HStack(spacing: 2) {
            Rectangle()
                .fill(Color.secondary.opacity(0.35))
                .frame(height: 1)

            Image(systemName: "chevron.right")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 16, maxWidth: .infinity)
    }

    private func trainBadge(for entry: ActiveTrainEntry) -> some View {
        let style = LineNumberColorScheme.style(forLineNumber: normalizedText(entry.trainMessage?.lineNumber))

        return Text(badgeText(for: entry))
            .font(.subheadline.monospacedDigit().weight(.bold))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(width: 58, height: 26)
            .lineNumberBadgeStyle(style)
    }

    private func badgeText(for entry: ActiveTrainEntry) -> String {
        normalizedText(entry.trainMessage?.lineNumber)
            ?? normalizedText(entry.stationMessage.trainNo)
            ?? normalizedText(entry.trainMessage?.trainNo)
            ?? normalizedText(entry.trainMessage?.advertisementTrainNo)
            ?? "-"
    }

    private func originText(for entry: ActiveTrainEntry) -> String {
        guard let trainMessage = entry.trainMessage,
              let origin = viewModel.displayName(forStationCode: trainMessage.origin, countryCode: trainMessage.countryCode)
        else {
            return "Ukjent"
        }

        return origin
    }

    private func destinationText(for entry: ActiveTrainEntry) -> String {
        guard let trainMessage = entry.trainMessage,
              let destination = viewModel.displayName(forStationCode: trainMessage.destination, countryCode: trainMessage.countryCode)
        else {
            return "Ukjent"
        }

        return destination
    }

    @ViewBuilder
    private func timeColumn(for stationMessage: StationMessage) -> some View {
        let scheduledText = scheduledTimeText(for: stationMessage)

        if let expectedText = expectedTimeText(for: stationMessage) {
            VStack(alignment: .leading, spacing: 2) {
                Text(expectedText)
                    .font(.title3.monospacedDigit().weight(.bold))
                    .foregroundStyle(ActiveTrainsBoardStyle.delayYellow)

                Text(scheduledText)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(ActiveTrainsBoardStyle.secondaryText)
                    .strikethrough(true, color: ActiveTrainsBoardStyle.secondaryText)
            }
        } else {
            Text(scheduledText)
                .font(.title3.monospacedDigit().weight(.bold))
                .foregroundStyle(.primary)
        }
    }

    private func scheduledTimeText(for stationMessage: StationMessage) -> String {
        let date = stationMessage.std ?? stationMessage.sta
        return date.map { AppTime.localTimeString(from: $0) } ?? "--:--"
    }

    private func expectedTimeText(for stationMessage: StationMessage) -> String? {
        guard let expected = stationMessage.etd ?? stationMessage.eta ?? stationMessage.atd ?? stationMessage.ata else {
            return nil
        }

        let expectedText = AppTime.localTimeString(from: expected)
        guard expectedText != scheduledTimeText(for: stationMessage) else {
            return nil
        }

        return expectedText
    }

    private func trackText(for stationMessage: StationMessage) -> String? {
        normalizedText(stationMessage.expectedTrack) ?? normalizedText(stationMessage.scheduledTrack)
    }

    private func normalizedText(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}

private enum ActiveTrainsBoardStyle {
    static let background = AppTheme.surface
    static let divider = AppTheme.border
    static let secondaryText = Color.secondary
    static let delayYellow = Color(red: 0.86, green: 0.62, blue: 0.0)
}

struct ActiveTrainEntry: Identifiable {
    let stationMessage: StationMessage
    let trainMessage: TrainMessage?
    let cityName: String

    var id: Int { stationMessage.id }
}

@MainActor
@Observable
final class ActiveTrainsTabViewModel {
    var entries: [ActiveTrainEntry] = []
    var filteredEntries: [ActiveTrainEntry] = []
    var errorMessage: String?
    var isLoading = false
    var searchText = ""

    private let service: SignalRService
    private let futureMinutes = 10
    private var hasStarted = false
    private var stationMessages: [StationMessage] = []
    private var stations: [TraseStation] = []
    private var stationNameLookup: [String: String] = [:]
    private var trainMessagesByKey: [String: TrainMessage] = [:]
    private var hasRequestedStations = false
    private var searchDebounceTask: Task<Void, Never>?

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
            self.stationNameLookup = self.makeStationNameLookup(from: stations)
            self.publishEntries()
        }

        service.onActiveStationMessages = { [weak self] stationMessages in
            guard let self else {
                return
            }

            self.stationMessages = stationMessages
            self.requestMissingTrainMessages(for: stationMessages)
            self.publishEntries()
            self.isLoading = false
            self.errorMessage = nil
        }

        service.onTrainMessage = { [weak self] trainMessage in
            guard let self else {
                return
            }

            let key = self.trainMessageKey(
                countryCode: trainMessage.countryCode,
                trainNo: trainMessage.trainNo,
                originDate: trainMessage.originDate
            )
            self.trainMessagesByKey[key] = trainMessage
            self.publishEntries()
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
        await service.requestActiveStationMessages(futureMinutes: futureMinutes)
    }

    func refresh() async {
        errorMessage = nil
        requestStationsIfNeeded(forceRefresh: true)
        await service.requestActiveStationMessages(futureMinutes: futureMinutes)
    }

    func stop() {
        hasStarted = false
        searchDebounceTask?.cancel()
        service.stop()
    }

    func updateSearchText(_ text: String) {
        searchText = text

        searchDebounceTask?.cancel()
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedText.isEmpty else {
            applySearch()
            return
        }

        searchDebounceTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else {
                return
            }

            await MainActor.run {
                self?.applySearch()
            }
        }
    }

    func displayName(forStationCode rawValue: String?, countryCode: String) -> String? {
        guard let normalized = normalizedText(rawValue) else {
            return nil
        }

        return displayStationName(for: normalized, countryCode: countryCode)
    }

    /// Uses the in-memory `SignalRService` train-message cache first (via `requestTrainMessage`,
    /// which returns immediately from cache when available) and only issues a fresh
    /// `GetTrainMessage` request for station messages not yet resolved locally.
    private func requestMissingTrainMessages(for stationMessages: [StationMessage]) {
        for stationMessage in stationMessages {
            let key = trainMessageKey(
                countryCode: stationMessage.countryCode,
                trainNo: stationMessage.trainNo,
                originDate: stationMessage.originDate
            )

            guard trainMessagesByKey[key] == nil else {
                continue
            }

            Task { [weak self] in
                guard let self else {
                    return
                }

                await self.service.requestTrainMessage(
                    countryCode: stationMessage.countryCode,
                    trainNo: stationMessage.trainNo,
                    originDate: stationMessage.originDate
                )
            }
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

    private func publishEntries() {
        entries = stationMessages
            .map { stationMessage in
                let key = trainMessageKey(
                    countryCode: stationMessage.countryCode,
                    trainNo: stationMessage.trainNo,
                    originDate: stationMessage.originDate
                )

                return ActiveTrainEntry(
                    stationMessage: stationMessage,
                    trainMessage: trainMessagesByKey[key],
                    cityName: displayStationName(for: stationMessage.city, countryCode: stationMessage.countryCode)
                )
            }
            .filter { sortDate(for: $0.stationMessage) >= AppTime.now.addingTimeInterval(60) }
            .sorted { sortDate(for: $0.stationMessage) < sortDate(for: $1.stationMessage) }
        applySearch()
    }

    private func applySearch() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty else {
            filteredEntries = entries
            return
        }

        filteredEntries = entries.filter { entry in
            searchableText(for: entry).localizedCaseInsensitiveContains(query)
        }
    }

    private func searchableText(for entry: ActiveTrainEntry) -> String {
        [
            entry.stationMessage.trainNo,
            entry.trainMessage?.trainNo,
            entry.trainMessage?.advertisementTrainNo,
            entry.trainMessage?.lineNumber,
            entry.cityName
        ]
        .compactMap { $0 }
        .joined(separator: " ")
    }

    private func sortDate(for stationMessage: StationMessage) -> Date {
        stationMessage.etd
            ?? stationMessage.eta
            ?? stationMessage.std
            ?? stationMessage.sta
            ?? stationMessage.originTime
            ?? .distantFuture
    }

    private func trainMessageKey(countryCode: String, trainNo: String, originDate: String) -> String {
        "\(countryCode)-\(trainNo)-\(originDate)"
    }

    private func displayStationName(for rawValue: String, countryCode: String) -> String {
        let normalizedValue = normalizedText(rawValue) ?? rawValue
        let key = stationLookupKey(countryCode: countryCode, value: normalizedValue)

        if let stationName = stationNameLookup[key] {
            return stationName
        }

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

    private func makeStationNameLookup(from stations: [TraseStation]) -> [String: String] {
        var lookup: [String: String] = [:]

        for station in stations {
            let stationName = station.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !stationName.isEmpty else {
                continue
            }

            let keys = [station.shortName, station.name, station.plcCode]
            for key in keys {
                guard let normalizedKey = normalizedText(key) else {
                    continue
                }

                lookup[stationLookupKey(countryCode: station.countryCode, value: normalizedKey)] = stationName
            }
        }

        return lookup
    }

    private func stationLookupKey(countryCode: String, value: String) -> String {
        let normalizedCountryCode = countryCode.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedValue = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return "\(normalizedCountryCode)|\(normalizedValue)"
    }

    private func normalizedText(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}
