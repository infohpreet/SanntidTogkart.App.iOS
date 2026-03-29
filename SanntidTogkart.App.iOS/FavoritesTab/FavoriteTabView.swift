import Observation
import SwiftUI

struct FavoriteTabView: View {
    @State private var favoriteStations = FavoriteStationsStore.shared
    @State private var viewModel = FavoriteTabViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if favoriteStations.favorites.isEmpty {
                    ContentUnavailableView(
                        "Ingen favoritter ennå",
                        systemImage: "star",
                        description: Text("Legg til favorittstasjoner fra Stasjoner-fanen for rask tilgang.")
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            favoritesHeader

                            LazyVStack(spacing: 16) {
                                ForEach(viewModel.cards) { card in
                                    NavigationLink {
                                        StationMessagesView(station: card.favorite.station)
                                    } label: {
                                        favoriteCard(for: card)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(16)
                    }
                    .refreshable {
                        await viewModel.refresh(favorites: favoriteStations.favorites)
                    }
                }
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Favoritter")
        }
        .task(id: favoriteStations.favorites) {
            await viewModel.refresh(favorites: favoriteStations.favorites)
        }
    }

    private var favoritesHeader: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Favorittstasjoner")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text("Se neste avgang og bla mellom meldinger direkte fra favorittene dine.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 3) {
                Text("\(favoriteStations.favorites.count)")
                    .font(.title3.monospacedDigit().weight(.bold))
                    .foregroundStyle(.primary)

                Text("stasjoner")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [AppTheme.surface, AppTheme.background],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.border, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.04), radius: 10, y: 4)
    }

    private func favoriteCard(for card: FavoriteStationCardState) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                favoriteCountryFlagBadge(for: card.favorite)

                VStack(alignment: .leading, spacing: 7) {
                    HStack(alignment: .center, spacing: 8) {
                        Text(card.favorite.name)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        if card.favorite.isBorderStation {
                            Text("Grense")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color.orange.opacity(0.10), in: Capsule())
                        }
                    }

                    Text(favoriteMetadataLine(for: card.favorite))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 12)

                Button {
                    favoriteStations.remove(card.favorite)
                } label: {
                    Image(systemName: "star.fill")
                        .font(.headline)
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 36, height: 36)
                        .background(AppTheme.surface, in: Circle())
                        .overlay {
                            Circle()
                                .stroke(AppTheme.border, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Fjern favoritt")
            }

            if card.isLoading {
                loadingMessageCard
            } else if let errorText = card.errorText {
                statusMessageCard(
                    title: "Kunne ikke hente meldinger",
                    subtitle: errorText,
                    systemImage: "exclamationmark.triangle.fill",
                    tint: .orange
                )
            } else if let stationMessage = card.selectedMessage {
                upcomingMessageCard(
                    card: card,
                    stationMessage: stationMessage,
                    trainDetail: card.trainDetail(for: stationMessage)
                )
            } else {
                statusMessageCard(
                    title: "Ingen kommende meldinger",
                    subtitle: "Denne favorittstasjonen har ingen meldinger tilgjengelig akkurat nå.",
                    systemImage: "clock.badge.exclamationmark",
                    tint: .secondary
                )
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [AppTheme.surface, AppTheme.elevatedSurface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 8)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.border, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.05), radius: 12, y: 6)
    }

    private var loadingMessageCard: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)

            Text("Laster neste stasjonsmelding...")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 16)
        .background(AppTheme.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.border, lineWidth: 1)
        }
    }

    private func statusMessageCard(title: String, subtitle: String, systemImage: String, tint: Color) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(tint)
                .frame(width: 40, height: 40)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 16)
        .background(AppTheme.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.border, lineWidth: 1)
        }
    }

    private func upcomingMessageCard(
        card: FavoriteStationCardState,
        stationMessage: StationMessage,
        trainDetail: TrainMessage?
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if let lineNumber = normalizedText(trainDetail?.lineNumber) {
                    Text(lineNumber)
                        .font(.headline.monospacedDigit().weight(.bold))
                        .foregroundStyle(.primary)

                    Text("•")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.secondary)
                }

                Text(displayTrainNumber(for: stationMessage, detail: trainDetail))
                    .font(.headline.monospacedDigit().weight(.bold))
                    .foregroundStyle(.primary)

                if let trainKind = normalizedText(stationMessage.trainKind) {
                    Text("•")
                        .foregroundStyle(.secondary)

                    Text(trainKind)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                if let scheduledTrack = normalizedText(stationMessage.scheduledTrack) {
                    Text("Spor \(scheduledTrack)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.accentColor.opacity(0.10), in: Capsule())
                }
            }

            if let routeText = displayRoute(for: trainDetail) {
                Text(routeText)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            HStack(spacing: 10) {
                infoPill(title: "Aktivitet", value: activityText(for: stationMessage))
                infoPill(title: "Planlagt", value: scheduledTime(for: stationMessage))
                infoPill(title: "Estimert", value: estimatedTime(for: stationMessage))
            }

            HStack(alignment: .center, spacing: 10) {
                Button {
                    viewModel.moveSelection(for: card.favorite.id, direction: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(card.canGoBackward ? Color.accentColor : .secondary.opacity(0.45))
                        .frame(width: 36, height: 36)
                        .background(AppTheme.surface, in: Circle())
                        .overlay {
                            Circle()
                                .stroke(AppTheme.border, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .disabled(!card.canGoBackward)

                VStack(spacing: 3) {
                    Text(messageTimingLabel(for: stationMessage))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text("Melding \(card.selectedIndex + 1) av \(card.messages.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                Button {
                    viewModel.moveSelection(for: card.favorite.id, direction: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(card.canGoForward ? Color.accentColor : .secondary.opacity(0.45))
                        .frame(width: 36, height: 36)
                        .background(AppTheme.surface, in: Circle())
                        .overlay {
                            Circle()
                                .stroke(AppTheme.border, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .disabled(!card.canGoForward)
            }
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [Color.accentColor.opacity(0.10), AppTheme.background],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 8)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.accentColor.opacity(0.14), lineWidth: 1)
        }
    }

    private func infoPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.caption.monospacedDigit().weight(.bold))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.border, lineWidth: 1)
        }
    }

    @ViewBuilder
    private func favoriteCountryFlagBadge(for favorite: FavoriteStation) -> some View {
        switch favorite.countryCode.uppercased() {
        case "NO":
            FavoriteNorwayFlagBadge()
        case "SE":
            FavoriteSwedenFlagBadge()
        default:
            Image(systemName: "building.columns.fill")
                .font(.headline)
                .foregroundStyle(Color.accentColor)
                .frame(width: 42, height: 28)
                .background(AppTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func favoriteMetadataLine(for favorite: FavoriteStation) -> String {
        [favorite.shortName, favorite.plcCode?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""]
            .filter { !$0.isEmpty }
            .joined(separator: " • ")
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

    private func activityText(for stationMessage: StationMessage) -> String {
        normalizedText(stationMessage.activity) ?? "Ukjent"
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

    private func messageTimingLabel(for stationMessage: StationMessage) -> String {
        if let actual = stationMessage.ata ?? stationMessage.atd {
            return "Faktisk \(displayTime(actual))"
        }

        if let estimated = stationMessage.eta ?? stationMessage.etd {
            return "Neste \(displayTime(estimated))"
        }

        if let scheduled = stationMessage.sta ?? stationMessage.std {
            return "Planlagt \(displayTime(scheduled))"
        }

        return "Tid ukjent"
    }

    private func displayTime(_ date: Date) -> String {
        date.formatted(
            .dateTime
                .hour(.twoDigits(amPM: .omitted))
                .minute(.twoDigits)
        )
    }

    private func displayRoute(for trainDetail: TrainMessage?) -> String? {
        guard let trainDetail else {
            return nil
        }

        let origin = viewModel.displayStationName(for: trainDetail.origin, countryCode: trainDetail.countryCode)
        let destination = viewModel.displayStationName(for: trainDetail.destination, countryCode: trainDetail.countryCode)

        switch (origin, destination) {
        case let (.some(origin), .some(destination)):
            return "\(origin) → \(destination)"
        case let (.some(origin), _):
            return origin
        case let (_, .some(destination)):
            return destination
        default:
            return nil
        }
    }
}

@MainActor
@Observable
private final class FavoriteTabViewModel {
    var cards: [FavoriteStationCardState] = []
    var stations: [TraseStation] = []

    private let service: SignalRService
    private var stationMessagesContinuation: CheckedContinuation<[StationMessage], Never>?
    private var trainMessageContinuation: CheckedContinuation<TrainMessage?, Never>?

    init() {
        service = SignalRService()
        configureBindings()
    }

    func refresh(favorites: [FavoriteStation]) async {
        guard !favorites.isEmpty else {
            cards = []
            return
        }

        cards = favorites.map { favorite in
            FavoriteStationCardState(
                favorite: favorite,
                messages: [],
                selectedIndex: 0,
                isLoading: true,
                errorText: nil
            )
        }

        await service.start()
        await service.requestStations()

        for favorite in favorites {
            let messages = await fetchStationMessages(for: favorite)
            updateCard(for: favorite, with: messages)

            if let selectedMessage = cards.first(where: { $0.id == favorite.id })?.selectedMessage {
                let trainDetail = await fetchTrainDetail(for: selectedMessage)
                attachTrainDetail(trainDetail, to: selectedMessage, favoriteID: favorite.id)
            }
        }
    }

    func moveSelection(for favoriteID: UUID, direction: Int) {
        guard let index = cards.firstIndex(where: { $0.id == favoriteID }) else {
            return
        }

        let nextIndex = cards[index].selectedIndex + direction
        guard cards[index].messages.indices.contains(nextIndex) else {
            return
        }

        cards[index].selectedIndex = nextIndex

        let favoriteID = cards[index].id
        let selectedMessage = cards[index].messages[nextIndex]
        let messageKey = messageKey(for: selectedMessage)
        guard cards[index].trainDetailsByMessageKey[messageKey] == nil else {
            return
        }

        Task {
            let trainDetail = await fetchTrainDetail(for: selectedMessage)
            await MainActor.run {
                attachTrainDetail(trainDetail, to: selectedMessage, favoriteID: favoriteID)
            }
        }
    }

    private func configureBindings() {
        service.onStations = { [weak self] stations in
            guard let self else {
                return
            }

            self.stations = stations
        }

        service.onStationMessages = { [weak self] stationMessages in
            guard let self, let continuation = self.stationMessagesContinuation else {
                return
            }

            self.stationMessagesContinuation = nil
            continuation.resume(returning: stationMessages)
        }

        service.onTrainMessage = { [weak self] trainMessage in
            guard let self, let continuation = self.trainMessageContinuation else {
                return
            }

            self.trainMessageContinuation = nil
            continuation.resume(returning: trainMessage)
        }

        service.onError = { [weak self] _ in
            guard let self else {
                return
            }

            if let continuation = self.stationMessagesContinuation {
                self.stationMessagesContinuation = nil
                continuation.resume(returning: [])
            } else if let continuation = self.trainMessageContinuation {
                self.trainMessageContinuation = nil
                continuation.resume(returning: nil)
            }
        }
    }

    private func fetchStationMessages(for favorite: FavoriteStation) async -> [StationMessage] {
        let originDate = AppTime.localDateString()

        return await withCheckedContinuation { continuation in
            stationMessagesContinuation = continuation
            Task {
                await service.requestStationMessages(
                    countryCode: favorite.countryCode,
                    stationShortName: favorite.shortName,
                    originDate: originDate
                )
            }
        }
    }

    private func updateCard(for favorite: FavoriteStation, with stationMessages: [StationMessage]) {
        guard let index = cards.firstIndex(where: { $0.id == favorite.id }) else {
            return
        }

        let orderedMessages = stationMessages.sorted { lhs, rhs in
            comparisonDate(for: lhs) < comparisonDate(for: rhs)
        }
        let initialIndex = nextUpcomingIndex(in: orderedMessages) ?? 0

        cards[index].messages = orderedMessages
        cards[index].selectedIndex = orderedMessages.isEmpty ? 0 : initialIndex
        cards[index].isLoading = false
        cards[index].errorText = orderedMessages.isEmpty ? "Ingen meldinger tilgjengelig." : nil
    }

    private func attachTrainDetail(_ trainDetail: TrainMessage?, to stationMessage: StationMessage, favoriteID: UUID) {
        guard
            let trainDetail,
            let index = cards.firstIndex(where: { $0.id == favoriteID })
        else {
            return
        }

        cards[index].trainDetailsByMessageKey[messageKey(for: stationMessage)] = trainDetail
    }

    private func nextUpcomingIndex(in messages: [StationMessage]) -> Int? {
        messages.firstIndex { comparisonDate(for: $0) >= AppTime.now }
    }

    private func fetchTrainDetail(for stationMessage: StationMessage) async -> TrainMessage? {
        await withCheckedContinuation { continuation in
            trainMessageContinuation = continuation
            Task {
                await service.requestTrainMessage(
                    countryCode: stationMessage.countryCode,
                    trainNo: stationMessage.trainNo,
                    originDate: stationMessage.originDate
                )
            }
        }
    }

    private func comparisonDate(for stationMessage: StationMessage) -> Date {
        stationMessage.ata
            ?? stationMessage.atd
            ?? stationMessage.eta
            ?? stationMessage.etd
            ?? stationMessage.sta
            ?? stationMessage.std
            ?? .distantFuture
    }

    private func messageKey(for stationMessage: StationMessage) -> String {
        "\(stationMessage.countryCode)-\(stationMessage.trainNo)-\(stationMessage.originDate)"
    }

    func displayStationName(for rawValue: String?, countryCode: String) -> String? {
        guard let normalizedValue = normalizedText(rawValue) else {
            return nil
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

    private func normalizedText(_ value: String?) -> String? {
        let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return normalized.isEmpty ? nil : normalized
    }
}

private struct FavoriteStationCardState: Identifiable {
    let favorite: FavoriteStation
    var messages: [StationMessage]
    var selectedIndex: Int
    var isLoading: Bool
    var errorText: String?
    var trainDetailsByMessageKey: [String: TrainMessage] = [:]

    var id: UUID { favorite.id }

    var selectedMessage: StationMessage? {
        guard messages.indices.contains(selectedIndex) else {
            return nil
        }

        return messages[selectedIndex]
    }

    var canGoBackward: Bool {
        selectedIndex > 0
    }

    var canGoForward: Bool {
        selectedIndex < messages.count - 1
    }

    func trainDetail(for stationMessage: StationMessage) -> TrainMessage? {
        trainDetailsByMessageKey["\(stationMessage.countryCode)-\(stationMessage.trainNo)-\(stationMessage.originDate)"]
    }
}

private struct FavoriteNorwayFlagBadge: View {
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

private struct FavoriteSwedenFlagBadge: View {
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
