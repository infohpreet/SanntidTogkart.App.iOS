import Observation
import SwiftUI

struct StationMessagesView: View {
    let station: TraseStation

    @State private var favoriteStations = FavoriteStationsStore.shared
    @State private var viewModel = StationMessagesViewModel()
    @State private var hasAutoScrolledToLatestPassedStation = false

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.stationMessages.isEmpty {
                ProgressView("Laster stasjonsmeldinger...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = viewModel.errorMessage, viewModel.stationMessages.isEmpty {
                ContentUnavailableView(
                    "Kunne ikke hente stasjonsmeldinger",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )
            } else if viewModel.stationMessages.isEmpty {
                ContentUnavailableView(
                    "Ingen stasjonsmeldinger",
                    systemImage: "tram.fill.tunnel",
                    description: Text("Ingen meldinger ble returnert for denne stasjonen.")
                )
            } else {
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            stationInfoCard

                            ForEach(viewModel.stationMessages) { stationMessage in
                                stationMessageRow(stationMessage)
                                    .id(stationMessage.id)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .appReadableContentWidth()
                    }
                    .refreshable {
                        await viewModel.refresh(for: station)
                    }
                    .onAppear {
                        scrollToLatestPassedStationIfNeeded(with: scrollProxy)
                    }
                    .onChange(of: viewModel.stationMessages.map(\.id)) { _, _ in
                        scrollToLatestPassedStationIfNeeded(with: scrollProxy)
                    }
                }
            }
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle(station.name)
        .task {
            await viewModel.start(for: station)
        }
    }

    private var latestPassedStationMessageID: Int? {
        let latestPassedStationMessage: StationMessage? = viewModel.stationMessages.last { stationMessage in
            isPastStationMessage(stationMessage)
        }

        return latestPassedStationMessage?.id
    }

    private func scrollToLatestPassedStationIfNeeded(with scrollProxy: ScrollViewProxy) {
        guard !hasAutoScrolledToLatestPassedStation,
              let latestPassedStationMessageID else {
            return
        }

        hasAutoScrolledToLatestPassedStation = true

        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.35)) {
                scrollProxy.scrollTo(latestPassedStationMessageID, anchor: .top)
            }
        }
    }

    private var stationInfoCard: some View {
        HStack(alignment: .center, spacing: 12) {
            stationCountryFlagBadge

            VStack(alignment: .leading, spacing: 6) {
                Text(station.name)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(stationMetadataLine)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 10) {
                Button {
                    favoriteStations.toggle(station)
                } label: {
                    Image(systemName: favoriteStations.isFavorite(station) ? "star.fill" : "star")
                        .font(.headline)
                        .foregroundStyle(favoriteStations.isFavorite(station) ? Color.accentColor : .secondary)
                        .frame(width: 36, height: 36)
                        .background(AppTheme.elevatedSurface, in: Circle())
                        .overlay {
                            Circle()
                                .stroke(AppTheme.border, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(favoriteStations.isFavorite(station) ? "Fjern favoritt" : "Legg til favoritt")

                Text(viewModel.originDate)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.border, lineWidth: 1)
        }
    }

    @ViewBuilder
    private func stationMessageRow(_ stationMessage: StationMessage) -> some View {
        let trainDetail = viewModel.trainDetail(for: stationMessage)
        if let trainDetail {
            NavigationLink {
                TrainStationsView(
                    trainMessage: trainDetail,
                    title: "Togrute"
                )
            } label: {
                stationMessageCard(stationMessage, trainDetail: trainDetail)
            }
            .buttonStyle(.plain)
        } else {
            stationMessageCard(stationMessage, trainDetail: nil)
        }
    }

    private func stationMessageCard(_ stationMessage: StationMessage, trainDetail: TrainMessage?) -> some View {
        let isPast = isPastStationMessage(stationMessage)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if let lineNumber = displayLineNumber(for: trainDetail) {
                    Text(lineNumber)
                        .font(.headline.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.primary)

                    Text("•")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }

                Text(displayTrainNumber(for: stationMessage, detail: trainDetail))
                    .font(.headline.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.primary)

                if let trainKind = normalizedText(stationMessage.trainKind) {
                    Text("•")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    Text(trainKind)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                if let scheduledTrack = normalizedText(stationMessage.scheduledTrack) {
                    Text(scheduledTrack)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                }
            }

            if let routeParts = viewModel.displayRouteParts(for: trainDetail) {
                HStack(spacing: 8) {
                    Text(routeParts.origin)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)

                    Image(systemName: "arrow.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(routeParts.destination)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }

            HStack(spacing: 8) {
                Text(stationMessage.originDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)

                HStack(spacing: 6) {
                    if isPast {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.green)
                    }

                    Text(normalizedText(stationMessage.activity) ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Rectangle()
                .fill(AppTheme.border)
                .frame(height: 1)

            Text("Ankomst")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            HStack(spacing: 18) {
                infoColumn(title: "Planlagt", value: scheduledTime(for: stationMessage))
                    .frame(maxWidth: .infinity, alignment: .leading)

                infoColumn(title: "Estimert", value: estimatedTime(for: stationMessage))
                    .frame(maxWidth: .infinity, alignment: .center)

                actualInfoColumn(
                    title: "Faktisk",
                    timeText: actualBaseTime(for: stationMessage.ata ?? stationMessage.atd),
                    delayText: actualDelayText(for: stationMessage.ata ?? stationMessage.atd, scheduledTime: stationMessage.sta ?? stationMessage.std),
                    alignment: .trailing,
                    delayColor: actualTimeColor(for: stationMessage.ata ?? stationMessage.atd, scheduledTime: stationMessage.sta ?? stationMessage.std)
                )
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            Text("Avgang")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            HStack(spacing: 18) {
                infoColumn(title: "Planlagt", value: scheduledDepartureTime(for: stationMessage))
                    .frame(maxWidth: .infinity, alignment: .leading)

                infoColumn(title: "Estimert", value: estimatedDepartureTime(for: stationMessage))
                    .frame(maxWidth: .infinity, alignment: .center)

                actualInfoColumn(
                    title: "Faktisk",
                    timeText: actualBaseTime(for: stationMessage.atd),
                    delayText: actualDelayText(for: stationMessage.atd, scheduledTime: stationMessage.std),
                    alignment: .trailing,
                    delayColor: actualTimeColor(for: stationMessage.atd, scheduledTime: stationMessage.std)
                )
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.border, lineWidth: 1)
        }
        .opacity(isPast ? 0.72 : 1)
    }

    private func infoColumn(
        title: String,
        value: String,
        alignment: HorizontalAlignment = .leading
    ) -> some View {
        VStack(alignment: alignment, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.primary)
        }
    }

    private func actualInfoColumn(
        title: String,
        timeText: String,
        delayText: String,
        alignment: HorizontalAlignment = .leading,
        delayColor: Color = .primary
    ) -> some View {
        VStack(alignment: alignment, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(
                "\(Text(timeText).foregroundStyle(.primary))\(Text(delayText).foregroundStyle(delayColor))"
            )
            .font(.subheadline.monospacedDigit())
        }
    }

    @ViewBuilder
    private var stationCountryFlagBadge: some View {
        switch station.countryCode.uppercased() {
        case "NO":
            StationMessagesNorwayFlagBadge()
        case "SE":
            StationMessagesSwedenFlagBadge()
        default:
            Image(systemName: "tram.fill.tunnel")
                .font(.headline)
                .foregroundStyle(Color.accentColor)
                .frame(width: 42, height: 28)
                .background(AppTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func scheduledTime(for stationMessage: StationMessage) -> String {
        if let scheduledTime = stationMessage.sta ?? stationMessage.std {
            return displayTime(scheduledTime)
        }

        return "Ukjent"
    }

    private func estimatedTime(for stationMessage: StationMessage) -> String {
        if let estimatedTime = stationMessage.eta ?? stationMessage.etd {
            return displayTime(estimatedTime)
        }

        return "Ukjent"
    }

    private func actualTime(for stationMessage: StationMessage) -> String {
        if let actualTime = stationMessage.ata ?? stationMessage.atd {
            return displayTimeWithDelay(actualTime, scheduledTime: stationMessage.sta ?? stationMessage.std)
        }

        return "Ukjent"
    }

    private func displayTime(_ date: Date) -> String {
        date.formatted(
            .dateTime
                .hour(.twoDigits(amPM: .omitted))
                .minute(.twoDigits)
        )
    }

    private func scheduledDepartureTime(for stationMessage: StationMessage) -> String {
        guard let scheduledTime = stationMessage.std else {
            return "Ukjent"
        }

        return displayTime(scheduledTime)
    }

    private func estimatedDepartureTime(for stationMessage: StationMessage) -> String {
        guard let estimatedTime = stationMessage.etd else {
            return "Ukjent"
        }

        return displayTime(estimatedTime)
    }

    private func displayTimeWithDelay(_ actualTime: Date, scheduledTime: Date?) -> String {
        let baseText = displayTime(actualTime)

        guard let scheduledTime else {
            return baseText
        }

        let delayMinutes = Int(actualTime.timeIntervalSince(scheduledTime) / 60)
        guard delayMinutes != 0 else {
            return baseText
        }

        let delayPrefix = delayMinutes > 0 ? "+" : ""
        return "\(baseText) (\(delayPrefix)\(delayMinutes))"
    }

    private func actualBaseTime(for actualTime: Date?) -> String {
        guard let actualTime else {
            return "Ukjent"
        }

        return displayTime(actualTime)
    }

    private func actualDelayText(for actualTime: Date?, scheduledTime: Date?) -> String {
        guard
            let actualTime,
            let scheduledTime
        else {
            return ""
        }

        let delayMinutes = Int(actualTime.timeIntervalSince(scheduledTime) / 60)
        guard delayMinutes != 0 else {
            return ""
        }

        let delayPrefix = delayMinutes > 0 ? "+" : ""
        return " (\(delayPrefix)\(delayMinutes))"
    }

    private func actualTimeColor(for actualTime: Date?, scheduledTime: Date?) -> Color {
        guard
            let actualTime,
            let scheduledTime
        else {
            return .primary
        }

        let delayMinutes = Int(actualTime.timeIntervalSince(scheduledTime) / 60)
        if delayMinutes > 0 {
            return .red
        }

        if delayMinutes < 0 {
            return .green
        }

        return .primary
    }

    private func isPastStationMessage(_ stationMessage: StationMessage) -> Bool {
        let referenceDate =
            stationMessage.ata
            ?? stationMessage.atd
            ?? stationMessage.eta
            ?? stationMessage.etd
            ?? stationMessage.sta
            ?? stationMessage.std

        guard let referenceDate else {
            return false
        }

        return referenceDate < AppTime.now
    }

    private func normalizedText(_ value: String?) -> String? {
        let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return normalized.isEmpty ? nil : normalized
    }

    private func displayTrainNumber(for stationMessage: StationMessage, detail: TrainMessage?) -> String {
        normalizedText(detail?.trainNo)
            ?? normalizedText(stationMessage.trainNo)
            ?? "Tog"
    }

    private func displayLineNumber(for detail: TrainMessage?) -> String? {
        normalizedText(detail?.lineNumber)
    }

    private var stationMetadataLine: String {
        let trimmedShortName = station.shortName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPlcCode = station.plcCode?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return [trimmedShortName, trimmedPlcCode]
            .filter { !$0.isEmpty }
            .joined(separator: " • ")
    }
}

private struct StationMessagesNorwayFlagBadge: View {
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

private struct StationMessagesSwedenFlagBadge: View {
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

@MainActor
@Observable
private final class StationMessagesViewModel {
    var stationMessages: [StationMessage] = []
    var errorMessage: String?
    var isLoading = false
    var originDate = ""
    var trainMessagesByKey: [String: TrainMessage] = [:]
    var stations: [TraseStation] = []

    private let service: SignalRService
    private var hasStarted = false

    init() {
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

        service.onStationMessages = { [weak self] stationMessages in
            guard let self else {
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
        guard !hasStarted else {
            return
        }

        hasStarted = true
        await loadStationMessages(for: station)
    }

    func refresh(for station: TraseStation) async {
        await loadStationMessages(for: station)
    }

    func trainDetail(for stationMessage: StationMessage) -> TrainMessage? {
        trainMessagesByKey[trainMessageKey(
            countryCode: stationMessage.countryCode,
            trainNo: stationMessage.trainNo,
            originDate: stationMessage.originDate
        )]
    }

    func displayRouteParts(for detail: TrainMessage?) -> (origin: String, destination: String)? {
        guard let detail else {
            return nil
        }

        guard
            let origin = normalizedText(detail.origin),
            let destination = normalizedText(detail.destination)
        else {
            return nil
        }

        return (
            displayStationName(for: origin, countryCode: detail.countryCode),
            displayStationName(for: destination, countryCode: detail.countryCode)
        )
    }

    private func loadStationMessages(for station: TraseStation) async {
        let stationShortName = station.shortName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !stationShortName.isEmpty else {
            stationMessages = []
            errorMessage = "Mangler stasjonskode."
            isLoading = false
            return
        }

        originDate = AppTime.localDateString()
        isLoading = true
        errorMessage = nil
        trainMessagesByKey = [:]

        await service.start()
        await service.requestStations()
        await service.requestStationMessages(
            countryCode: station.countryCode,
            stationShortName: stationShortName,
            originDate: originDate
        )
    }

    private func requestTrainDetails(for stationMessages: [StationMessage]) {
        for stationMessage in stationMessages {
            Task {
                await service.requestTrainMessage(
                    countryCode: stationMessage.countryCode,
                    trainNo: stationMessage.trainNo,
                    originDate: stationMessage.originDate
                )
            }
        }
    }

    private func trainMessageKey(for trainMessage: TrainMessage) -> String {
        trainMessageKey(
            countryCode: trainMessage.countryCode,
            trainNo: trainMessage.trainNo,
            originDate: trainMessage.originDate
        )
    }

    private func trainMessageKey(countryCode: String, trainNo: String, originDate: String) -> String {
        "\(countryCode)-\(trainNo)-\(originDate)"
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
