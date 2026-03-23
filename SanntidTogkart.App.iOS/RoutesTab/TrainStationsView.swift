import Observation
import SwiftUI

struct TrainStationsView: View {
    let trainMessage: TrainMessage
    let title: String

    @State private var viewModel = TrainStationsViewModel()

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
                    systemImage: "building.2",
                    description: Text("Ingen meldinger ble returnert for dette toget.")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        trainInfoCard

                        ForEach(viewModel.stationMessages) { stationMessage in
                            stationMessageRow(stationMessage)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .refreshable {
                    await viewModel.refresh(for: trainMessage)
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.start(for: trainMessage)
        }
    }

    private var trainInfoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                trainCountryFlagBadge

                Text(displayLineNumber)
                    .font(.headline.monospacedDigit().weight(.bold))
                    .foregroundStyle(.primary)

                if hasDistinctLineNumber {
                    Text("•")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    Text(displayTrainNumber)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Text(trainMessage.originDate)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            HStack(spacing: 8) {
                Spacer(minLength: 0)

                Text(routeOriginText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)

                Image(systemName: "arrow.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(routeDestinationText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)

                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                Text(displayCompany)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                if let trainType = normalizedText(trainMessage.trainType) {
                    Text(trainType)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        }
    }

    private var displayTrainNumber: String {
        let trainNumber = trainMessage.trainNo.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trainNumber.isEmpty {
            return trainNumber
        }

        return trainMessage.advertisementTrainNo
    }

    private var displayLineNumber: String {
        let lineNumber = trainMessage.lineNumber?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !lineNumber.isEmpty {
            return lineNumber
        }

        return displayTrainNumber
    }

    private var hasDistinctLineNumber: Bool {
        let lineNumber = trainMessage.lineNumber?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !lineNumber.isEmpty && lineNumber != displayTrainNumber
    }

    private var displayCompany: String {
        normalizedText(trainMessage.company)
            ?? normalizedText(trainMessage.trainPosition?.toc)
            ?? normalizedText(trainMessage.trainPosition?.geoJson.properties.operatorRef)
            ?? "Operatør mangler"
    }

    private var routeText: String {
        let parts = [trainMessage.origin, trainMessage.destination]
            .compactMap { normalizedText($0) }
            .map { viewModel.displayStationName(for: $0, countryCode: trainMessage.countryCode) }

        if parts.isEmpty {
            return title
        }

        return parts.joined(separator: " - ")
    }

    private var routeOriginText: String {
        normalizedText(trainMessage.origin)
            .map { viewModel.displayStationName(for: $0, countryCode: trainMessage.countryCode) }
            ?? title
    }

    private var routeDestinationText: String {
        normalizedText(trainMessage.destination)
            .map { viewModel.displayStationName(for: $0, countryCode: trainMessage.countryCode) }
            ?? ""
    }

    private func stationMessageRow(_ stationMessage: StationMessage) -> some View {
        let stationDisplay = viewModel.stationDisplay(for: stationMessage.city, countryCode: stationMessage.countryCode)
        let isPast = isPastStationMessage(stationMessage)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(stationDisplay.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let shortName = stationDisplay.shortName, !shortName.isEmpty {
                    Text("•")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    Text(shortName)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let shortName = stationDisplay.shortName, !shortName.isEmpty,
                   let plcCode = stationDisplay.plcCode, !plcCode.isEmpty {
                    Text("•")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }

                if let plcCode = stationDisplay.plcCode, !plcCode.isEmpty {
                    Text(plcCode)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                if let scheduledTrack = stationMessage.scheduledTrack, !scheduledTrack.isEmpty {
                    Text(scheduledTrack)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
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

                    Text(stationMessage.activity)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Divider()

            HStack(spacing: 18) {
                infoColumn(
                    title: "Planlagt",
                    value: scheduledTime(for: stationMessage)
                )
                .frame(maxWidth: .infinity, alignment: .leading)

                infoColumn(
                    title: "Estimert",
                    value: estimatedTime(for: stationMessage)
                )
                .frame(maxWidth: .infinity, alignment: .center)

                infoColumn(
                    title: "Faktisk",
                    value: actualTime(for: stationMessage)
                )
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        }
        .opacity(isPast ? 0.72 : 1)
    }

    private func infoColumn(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.primary)
        }
    }

    private func primaryTime(for stationMessage: StationMessage) -> String {
        if let estimatedTime = stationMessage.eta ?? stationMessage.etd {
            return displayTime(estimatedTime)
        }

        if let scheduledTime = stationMessage.sta ?? stationMessage.std {
            return displayTime(scheduledTime)
        }

        return "Ukjent"
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
            return displayTime(actualTime)
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

    @ViewBuilder
    private var trainCountryFlagBadge: some View {
        switch trainMessage.countryCode.uppercased() {
        case "NO":
            TrainStationsNorwayFlagBadge()
        case "SE":
            TrainStationsSwedenFlagBadge()
        default:
            Image(systemName: "tram.fill")
                .font(.headline)
                .foregroundStyle(Color.accentColor)
                .frame(width: 42, height: 28)
                .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        }
    }

}

private struct TrainStationsNorwayFlagBadge: View {
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
    }
}

private struct TrainStationsSwedenFlagBadge: View {
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
    }
}

@MainActor
@Observable
private final class TrainStationsViewModel {
    var stationMessages: [StationMessage] = []
    var errorMessage: String?
    var isLoading = false

    private let service: SignalRService
    private var hasStarted = false
    private var stations: [TraseStation] = []

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

        service.onTrainStations = { [weak self] stationMessages in
            guard let self else {
                return
            }

            self.stationMessages = stationMessages
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

    func start(for trainMessage: TrainMessage) async {
        guard !hasStarted else {
            return
        }

        hasStarted = true
        await loadStationMessages(for: trainMessage)
    }

    func refresh(for trainMessage: TrainMessage) async {
        await loadStationMessages(for: trainMessage)
    }

    func displayStationName(for rawValue: String, countryCode: String) -> String {
        stationDisplay(for: rawValue, countryCode: countryCode).name
    }

    func stationDisplay(for rawValue: String, countryCode: String) -> StationDisplay {
        let normalizedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedValue.isEmpty else {
            return StationDisplay(name: rawValue, shortName: nil, plcCode: nil)
        }

        if let station = stations.first(where: { station in
            station.countryCode.localizedCaseInsensitiveCompare(countryCode) == .orderedSame
                && (
                    station.shortName.localizedCaseInsensitiveCompare(normalizedValue) == .orderedSame
                        || station.name.localizedCaseInsensitiveCompare(normalizedValue) == .orderedSame
                        || (station.plcCode?.localizedCaseInsensitiveCompare(normalizedValue) == .orderedSame)
                )
        }) {
            return StationDisplay(
                name: station.name,
                shortName: station.shortName,
                plcCode: station.plcCode
            )
        }

        return StationDisplay(name: rawValue, shortName: nil, plcCode: nil)
    }

    private func loadStationMessages(for trainMessage: TrainMessage) async {
        let trainNumber = trainMessage.trainNo.trimmingCharacters(in: .whitespacesAndNewlines)
        let advertisementTrainNo = trainMessage.advertisementTrainNo.trimmingCharacters(in: .whitespacesAndNewlines)
        let requestedTrainNumber = trainNumber.isEmpty ? advertisementTrainNo : trainNumber

        guard !requestedTrainNumber.isEmpty else {
            stationMessages = []
            errorMessage = "Mangler tognummer."
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil
        await service.start()
        await service.requestStations()
        await service.requestTrainStations(
            countryCode: trainMessage.countryCode,
            trainNumber: requestedTrainNumber,
            originDate: trainMessage.originDate
        )
    }
}

private struct StationDisplay {
    let name: String
    let shortName: String?
    let plcCode: String?
}
