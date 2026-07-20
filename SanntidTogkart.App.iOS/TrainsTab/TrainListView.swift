import Observation
import SwiftUI

struct TrainListView: View {
    let station: TraseStation

    @State private var favoritesStore = TrainStationFavoritesStore.shared
    @State private var filterStore = TrainListStationFilterStore.shared
    @State private var selectedTab: TrainListTab = .departures
    @State private var isFilterCardExpanded = false
    @State private var selectedLineNumberFilters: Set<String> = []
    @State private var selectedTrackFilters: Set<String> = []
    @State private var viewModel = TrainListViewModel()

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
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        trainListTabPicker
                        filterCard

                        stationMessagesBoard
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 16)
                    .appReadableContentWidth()
                }
                .scrollIndicators(.hidden)
                .refreshable {
                    await viewModel.refresh(for: station)
                }
            }
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle(station.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    favoritesStore.toggle(station)
                } label: {
                    Image(systemName: favoritesStore.isFavorite(station) ? "star.fill" : "star")
                        .foregroundStyle(favoritesStore.isFavorite(station) ? Color.accentColor : .secondary)
                }
                .accessibilityLabel(favoritesStore.isFavorite(station) ? "Fjern favoritt" : "Legg til favoritt")
            }
        }
        .task {
            applyPersistedFilters()
            await viewModel.start(for: station)
        }
        .onChange(of: selectedLineNumberFilters) { _, _ in
            persistSelectedFilters()
        }
        .onChange(of: selectedTrackFilters) { _, _ in
            persistSelectedFilters()
        }
    }

    private func messages(for tab: TrainListTab) -> [StationMessage] {
        viewModel.filteredMessages(
            for: tab,
            lineNumberFilters: selectedLineNumberFilters,
            trackFilters: selectedTrackFilters
        )
    }

    private var hasActiveFilters: Bool {
        !selectedLineNumberFilters.isEmpty || !selectedTrackFilters.isEmpty
    }

    private var lineNumberFilterOptions: [String] {
        optionsIncludingSelected(
            viewModel.availableLineNumberFilters(for: selectedTab, trackFilters: selectedTrackFilters),
            selected: selectedLineNumberFilters
        )
    }

    private var trackFilterOptions: [String] {
        optionsIncludingSelected(
            viewModel.availableTrackFilters(for: selectedTab, lineNumberFilters: selectedLineNumberFilters),
            selected: selectedTrackFilters
        )
    }

    private var filterCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isFilterCardExpanded.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    if hasActiveFilters {
                        Text(activeFilterSummary)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: isFilterCardExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isFilterCardExpanded {
                VStack(alignment: .leading, spacing: 16) {
                    if hasActiveFilters {
                        Button("Nullstill") {
                            selectedLineNumberFilters.removeAll()
                            selectedTrackFilters.removeAll()
                        }
                        .font(.caption.weight(.semibold))
                    }

                    filterOptionSection(
                        title: "Linje",
                        options: lineNumberFilterOptions,
                        selected: selectedLineNumberFilters,
                        toggle: toggleLineNumberFilter
                    )

                    filterOptionSection(
                        title: "Spor",
                        options: trackFilterOptions,
                        selected: selectedTrackFilters,
                        toggle: toggleTrackFilter
                    )
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(12)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        }
    }

    private var activeFilterSummary: String {
        let line = summaryText(for: selectedLineNumberFilters).map { "Linje \($0)" }
        let track = summaryText(for: selectedTrackFilters).map { "Spor \($0)" }

        return [line, track]
            .compactMap { $0 }
            .joined(separator: " • ")
    }

    private func summaryText(for values: Set<String>) -> String? {
        guard !values.isEmpty else {
            return nil
        }

        return values
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            .joined(separator: ", ")
    }

    private func filterOptionSection(
        title: String,
        options: [String],
        selected: Set<String>,
        toggle: @escaping (String) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if options.isEmpty {
                Text("Ingen alternativer")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(options, id: \.self) { option in
                        filterChip(title: option, isSelected: selected.contains(option)) {
                            toggle(option)
                        }
                    }
                }
            }
        }
    }

    private func filterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? .white : .primary)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    isSelected ? Color.accentColor : AppTheme.background,
                    in: Capsule(style: .continuous)
                )
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(AppTheme.border, lineWidth: isSelected ? 0 : 1)
                }
        }
        .buttonStyle(.plain)
    }

    private func toggleLineNumberFilter(_ value: String) {
        if selectedLineNumberFilters.contains(value) {
            selectedLineNumberFilters.remove(value)
        } else {
            selectedLineNumberFilters.insert(value)
        }
    }

    private func toggleTrackFilter(_ value: String) {
        if selectedTrackFilters.contains(value) {
            selectedTrackFilters.remove(value)
        } else {
            selectedTrackFilters.insert(value)
        }
    }

    private func optionsIncludingSelected(_ options: [String], selected: Set<String>) -> [String] {
        let missingSelected = selected.filter { selectedValue in
            !options.contains { $0.localizedCaseInsensitiveCompare(selectedValue) == .orderedSame }
        }

        guard !missingSelected.isEmpty else {
            return options
        }

        return (options + missingSelected).sorted { lhs, rhs in
            lhs.localizedStandardCompare(rhs) == .orderedAscending
        }
    }

    private func applyPersistedFilters() {
        let persistedFilter = filterStore.filter(for: station.storageKey)
        selectedLineNumberFilters = persistedFilter.lineNumbers
        selectedTrackFilters = persistedFilter.tracks
    }

    private func persistSelectedFilters() {
        filterStore.setFilter(
            for: station.storageKey,
            lineNumbers: selectedLineNumberFilters,
            tracks: selectedTrackFilters
        )
    }

    private var trainListTabPicker: some View {
        HStack(spacing: 0) {
            ForEach(TrainListTab.allCases) { tab in
                Button {
                    selectTab(tab)
                } label: {
                    Text(tab.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(selectedTab == tab ? .white : Color.accentColor)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background {
                            if selectedTab == tab {
                                Capsule(style: .continuous)
                                    .fill(Color.accentColor)
                            }
                        }
                        .contentShape(Capsule(style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
            }
        }
        .padding(0)
        .background(Color.accentColor.opacity(0.12), in: Capsule(style: .continuous))
        .clipShape(Capsule(style: .continuous))
    }

    private var stationMessagesBoard: some View {
        stationMessagesBoardPage(for: selectedTab)
            .gesture(tabSwipeGesture)
    }

    private var tabSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 24, coordinateSpace: .local)
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else {
                    return
                }

                if value.translation.width < -40 {
                    selectTab(.arrivals)
                } else if value.translation.width > 40 {
                    selectTab(.departures)
                }
            }
    }

    private func selectTab(_ tab: TrainListTab) {
        guard selectedTab != tab else {
            return
        }

        withAnimation(.easeInOut(duration: 0.18)) {
            selectedTab = tab
        }
    }

    @ViewBuilder
    private func stationMessagesBoardPage(for tab: TrainListTab) -> some View {
        let tabMessages = messages(for: tab)
        let remainingMessages = Array(tabMessages.dropFirst())

        if tabMessages.isEmpty {
            emptyBoard(for: tab)
        } else {
            LazyVStack(spacing: 0) {
                trainRouteLink(for: tabMessages[0], tab: tab) {
                    boardHero(for: tabMessages[0], tab: tab)
                }

                if !remainingMessages.isEmpty {
                    boardHeader(for: tab)

                    ForEach(Array(remainingMessages.enumerated()), id: \.element.id) { index, stationMessage in
                        trainRouteLink(for: stationMessage, tab: tab) {
                            boardRow(stationMessage, tab: tab)
                        }

                        if index < remainingMessages.count - 1 {
                            Rectangle()
                                .fill(TrainListBoardStyle.divider)
                                .frame(height: 1)
                                .padding(.horizontal, 18)
                        }
                    }
                }
            }
            .background(TrainListBoardStyle.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private func trainRouteLink<Label: View>(
        for stationMessage: StationMessage,
        tab: TrainListTab,
        @ViewBuilder label: () -> Label
    ) -> some View {
        NavigationLink {
            TrainRouteView(
                station: station,
                stationMessage: stationMessage,
                trainMessage: viewModel.trainDetail(for: stationMessage),
                direction: trainRouteDirection(for: tab)
            )
        } label: {
            label()
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func trainRouteDirection(for tab: TrainListTab) -> TrainRouteDirection {
        switch tab {
        case .departures:
            return .departure
        case .arrivals:
            return .arrival
        }
    }

    private func emptyBoard(for tab: TrainListTab) -> some View {
        VStack(spacing: 10) {
            Image(systemName: tab.emptySystemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 44, height: 44)
                .background(Color.accentColor.opacity(0.10), in: Circle())

            Text(tab.emptyTitle)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        }
    }

    private func boardHero(for stationMessage: StationMessage, tab: TrainListTab) -> some View {
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
                Text(viewModel.stationText(for: stationMessage, tab: tab))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(viewModel.scheduledTimeText(for: stationMessage, tab: tab))
                        .font(.title3.monospacedDigit().weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    if let expectedTimeText = viewModel.expectedTimeDisplayText(for: stationMessage, tab: tab),
                       expectedTimeText != viewModel.scheduledTimeText(for: stationMessage, tab: tab) {
                        Text(expectedTimeText)
                            .font(.subheadline.monospacedDigit().weight(.semibold))
                            .foregroundStyle(TrainListBoardStyle.delayYellow)
                            .lineLimit(1)

                        Text("Forventet")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(TrainListBoardStyle.delayYellow)
                    }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 24)
        .padding(.bottom, 22)
    }

    private func boardHeader(for tab: TrainListTab) -> some View {
        VStack(spacing: 10) {
            Rectangle()
                .fill(TrainListBoardStyle.divider)
                .frame(height: 1)

            HStack(spacing: 10) {
                Text(tab.timeColumnTitle)
                    .frame(width: 56, alignment: .leading)

                Text(tab.destinationColumnTitle)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("Spor")
                    .frame(width: 30, alignment: .trailing)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(TrainListBoardStyle.mutedText)
            .padding(.horizontal, 18)
        }
        .padding(.bottom, 6)
    }

    private func boardRow(_ stationMessage: StationMessage, tab: TrainListTab) -> some View {
        HStack(alignment: .center, spacing: 10) {
            timeColumn(for: stationMessage, tab: tab)
                .frame(width: 56, alignment: .leading)

            HStack(spacing: 8) {
                trainBadge(for: stationMessage, size: .small)

                Text(viewModel.stationText(for: stationMessage, tab: tab))
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
    private func timeColumn(for stationMessage: StationMessage, tab: TrainListTab) -> some View {
        let scheduledText = viewModel.scheduledTimeText(for: stationMessage, tab: tab)
        let expectedText = viewModel.expectedTimeDisplayText(for: stationMessage, tab: tab)

        if let expectedText, expectedText != scheduledText {
            VStack(alignment: .leading, spacing: 2) {
                Text(expectedText)
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .foregroundStyle(TrainListBoardStyle.delayYellow)

                Text(scheduledText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(TrainListBoardStyle.secondaryText)
                    .strikethrough(true, color: TrainListBoardStyle.secondaryText)
            }
        } else {
            Text(scheduledText)
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .foregroundStyle(.primary)
        }
    }

    private func trainBadge(for stationMessage: StationMessage, size: TrainBadgeSize) -> some View {
        let isFreightTrain = CommonService.isFreightTrainCompany(
            viewModel.trainDetail(for: stationMessage)?.company
        )

        return Text(viewModel.trainDisplayText(for: stationMessage))
            .font(size.font)
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(width: size.width, height: size.height)
            .background(
                isFreightTrain ? TrainListBoardStyle.freightGreen : TrainListBoardStyle.trainRed,
                in: RoundedRectangle(cornerRadius: 1)
            )
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var origin = CGPoint.zero
        var rowHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if origin.x + size.width > maxWidth, origin.x > 0 {
                origin.x = 0
                origin.y += rowHeight + spacing
                rowHeight = 0
            }

            origin.x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            totalWidth = max(totalWidth, origin.x - spacing)
        }

        return CGSize(width: totalWidth, height: origin.y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var origin = bounds.origin
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if origin.x + size.width > bounds.maxX, origin.x > bounds.minX {
                origin.x = bounds.minX
                origin.y += rowHeight + spacing
                rowHeight = 0
            }

            subview.place(at: origin, proposal: ProposedViewSize(size))
            origin.x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

private enum TrainListTab: CaseIterable, Identifiable {
    case departures
    case arrivals

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .departures:
            return "Avganger"
        case .arrivals:
            return "Ankomster"
        }
    }

    var timeColumnTitle: String {
        switch self {
        case .departures:
            return "Avgang"
        case .arrivals:
            return "Ankomst"
        }
    }

    var destinationColumnTitle: String {
        switch self {
        case .departures:
            return "Tog til"
        case .arrivals:
            return "Tog fra"
        }
    }

    var emptyTitle: String {
        switch self {
        case .departures:
            return "Ingen avganger"
        case .arrivals:
            return "Ingen ankomster"
        }
    }

    var emptySystemImage: String {
        switch self {
        case .departures:
            return "arrow.up.right"
        case .arrivals:
            return "arrow.down.left"
        }
    }
}

private enum TrainBadgeSize {
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

private enum TrainListBoardStyle {
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
private final class TrainListViewModel {
    private let maxUpcomingMessages = 50
    private let upcomingRequestCount = 150
    private(set) var stationMessages: [StationMessage] = []
    private var trainMessagesByKey: [String: TrainMessage] = [:]
    private var stations: [TraseStation] = []
    private var requestedStationKey: String?
    private var requestedStationShortName: String?
    private var requestedStationName: String?
    private var requestedCountryCode: String?
    var errorMessage: String?
    var isLoading = false

    private let service: SignalRService
    private var hasStarted = false

    init() {
        self.service = SignalRService()
        configureBindings()
    }

    var departureMessages: [StationMessage] {
        filteredMessages(for: .departures, lineNumberFilters: [], trackFilters: [])
    }

    var arrivalMessages: [StationMessage] {
        filteredMessages(for: .arrivals, lineNumberFilters: [], trackFilters: [])
    }

    func filteredMessages(for tab: TrainListTab, lineNumberFilters: Set<String>, trackFilters: Set<String>) -> [StationMessage] {
        Array(baseMessages(for: tab)
            .filter { matchesFilters($0, lineNumberFilters: lineNumberFilters, trackFilters: trackFilters) })
    }

    func availableLineNumberFilters(for tab: TrainListTab, trackFilters: Set<String>) -> [String] {
        uniqueSortedValues(
            from: baseMessages(for: tab)
                .filter { matchesFilters($0, lineNumberFilters: [], trackFilters: trackFilters) }
                .compactMap { lineNumberOptionValue(for: $0) }
        )
    }

    func availableTrackFilters(for tab: TrainListTab, lineNumberFilters: Set<String>) -> [String] {
        uniqueSortedValues(
            from: baseMessages(for: tab)
                .filter { matchesFilters($0, lineNumberFilters: lineNumberFilters, trackFilters: []) }
                .compactMap { trackFilterValue(for: $0) }
        )
    }

    private func configureBindings() {
        service.onStations = { [weak self] stations in
            guard let self else {
                return
            }

            self.stations = stations
        }

        service.onStationMessagesUpcoming = { [weak self] stationMessages in
            guard let self,
                  self.matchesRequestedStation(stationMessages) else {
                return
            }

            self.stationMessages = stationMessages
            self.requestTrainDetailsForInitialView(for: stationMessages)
            self.errorMessage = nil
            self.isLoading = false
        }

        service.onTrainMessage = { [weak self] trainMessage in
            guard let self else {
                return
            }

            let key = self.trainMessageKey(for: trainMessage)
            var updated = self.trainMessagesByKey
            updated[key] = trainMessage
            self.trainMessagesByKey = updated
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

    func trainDisplayText(for stationMessage: StationMessage) -> String {
        normalizedText(trainDetail(for: stationMessage)?.lineNumber)
            ?? normalizedText(stationMessage.trainNo)
            ?? "-"
    }

    func stationText(for stationMessage: StationMessage, tab: TrainListTab) -> String {
        let trainMessage = trainDetail(for: stationMessage)
        let rawStationName: String?

        switch tab {
        case .departures:
            rawStationName = normalizedText(trainMessage?.destination) ?? normalizedText(stationMessage.city)
        case .arrivals:
            rawStationName = normalizedText(trainMessage?.origin) ?? normalizedText(stationMessage.city)
        }

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

    func primaryTimeText(for stationMessage: StationMessage, tab: TrainListTab) -> String {
        expectedTimeText(for: stationMessage, tab: tab, fallbackToScheduled: true)
    }

    func expectedTimeDisplayText(for stationMessage: StationMessage, tab: TrainListTab) -> String? {
        let expectedText = expectedTimeText(for: stationMessage, tab: tab)
        return expectedText.isEmpty ? nil : expectedText
    }

    func scheduledTimeText(for stationMessage: StationMessage, tab: TrainListTab) -> String {
        let date: Date?
        switch tab {
        case .departures:
            date = stationMessage.std
        case .arrivals:
            date = stationMessage.sta
        }

        return date.map { AppTime.localTimeString(from: $0) } ?? "--:--"
    }

    func expectedTimeText(for stationMessage: StationMessage, tab: TrainListTab, fallbackToScheduled: Bool = false) -> String {
        let expectedDate: Date?
        let scheduledDate: Date?

        switch tab {
        case .departures:
            expectedDate = stationMessage.etd ?? stationMessage.atd
            scheduledDate = stationMessage.std
        case .arrivals:
            expectedDate = stationMessage.eta ?? stationMessage.ata
            scheduledDate = stationMessage.sta
        }

        if let expectedDate {
            return AppTime.localTimeString(from: expectedDate)
        }

        if fallbackToScheduled, let scheduledDate {
            return AppTime.localTimeString(from: scheduledDate)
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

        isLoading = true
        errorMessage = nil
        trainMessagesByKey = [:]
        requestedStationKey = station.storageKey
        requestedStationShortName = stationShortName
        requestedStationName = station.name.trimmingCharacters(in: .whitespacesAndNewlines)
        requestedCountryCode = station.countryCode.trimmingCharacters(in: .whitespacesAndNewlines)

        await service.start()
        await service.requestStations()
        await service.requestStationMessagesUpcoming(
            countryCode: station.countryCode,
            stationShortName: stationShortName,
            count: upcomingRequestCount
        )
    }

    private func matchesRequestedStation(_ stationMessages: [StationMessage]) -> Bool {
        guard requestedStationKey != nil else {
            return false
        }

        guard !stationMessages.isEmpty else {
            // Keep first-load empty-state support without allowing unrelated background updates to clear loaded data.
            return isLoading
        }

        guard
            let requestedStationKey,
            let requestedStationShortName,
            let requestedStationName,
            let requestedCountryCode
        else {
            return false
        }

        let normalizedRequestedCountryCode = requestedCountryCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let requestedCandidates = stationMatchCandidates(from: [requestedStationShortName, requestedStationName])

        return stationMessages.contains { stationMessage in
            let normalizedResponseCountryCode = stationMessage.countryCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            guard normalizedRequestedCountryCode == normalizedResponseCountryCode else {
                return false
            }

            let responseCandidates = stationMatchCandidates(from: [stationMessage.city])
            if !requestedCandidates.isDisjoint(with: responseCandidates) {
                return true
            }

            if let responseStation = stations.first(where: { station in
                station.countryCode.compare(normalizedResponseCountryCode, options: .caseInsensitive) == .orderedSame
                    && (
                        station.shortName.compare(stationMessage.city, options: .caseInsensitive) == .orderedSame
                            || station.name.compare(stationMessage.city, options: .caseInsensitive) == .orderedSame
                            || (station.plcCode?.compare(stationMessage.city, options: .caseInsensitive) == .orderedSame)
                    )
            }) {
                return responseStation.storageKey == requestedStationKey
            }

            return false
        }
    }

    private func requestTrainDetailsForInitialView(for stationMessages: [StationMessage]) {
        let prioritizedMessages = prioritizedMessagesForInitialView(from: stationMessages)
        let prioritizedKeys = Set(prioritizedMessages.map(trainMessageKey(for:)))
        let remainingMessages = stationMessages.filter { !prioritizedKeys.contains(trainMessageKey(for: $0)) }

        Task {
            for stationMessage in prioritizedMessages {
                await service.requestTrainMessage(
                    countryCode: stationMessage.countryCode,
                    trainNo: stationMessage.trainNo,
                    originDate: stationMessage.originDate
                )
            }

            for stationMessage in remainingMessages {
                await service.requestTrainMessage(
                    countryCode: stationMessage.countryCode,
                    trainNo: stationMessage.trainNo,
                    originDate: stationMessage.originDate
                )
            }
        }
    }

    private func prioritizedMessagesForInitialView(from stationMessages: [StationMessage]) -> [StationMessage] {
        let prioritizedDepartures = Array(stationMessages
            .filter { isVisible($0, tab: .departures) }
            .sorted { lhs, rhs in compare(lhs: lhs, rhs: rhs, tab: .departures) }
            .prefix(maxUpcomingMessages))

        let prioritizedArrivals = Array(stationMessages
            .filter { isVisible($0, tab: .arrivals) }
            .sorted { lhs, rhs in compare(lhs: lhs, rhs: rhs, tab: .arrivals) }
            .prefix(maxUpcomingMessages))

        var seenKeys: Set<String> = []
        var prioritized: [StationMessage] = []

        for stationMessage in prioritizedDepartures + prioritizedArrivals {
            let key = trainMessageKey(for: stationMessage)
            if seenKeys.insert(key).inserted {
                prioritized.append(stationMessage)
            }
        }

        return prioritized
    }

    func trainDetail(for stationMessage: StationMessage) -> TrainMessage? {
        trainMessagesByKey[trainMessageKey(
            countryCode: stationMessage.countryCode,
            trainNo: stationMessage.trainNo,
            originDate: stationMessage.originDate
        )]
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

    private func trainMessageKey(for stationMessage: StationMessage) -> String {
        trainMessageKey(
            countryCode: stationMessage.countryCode,
            trainNo: stationMessage.trainNo,
            originDate: stationMessage.originDate
        )
    }

    private func isVisible(_ stationMessage: StationMessage, tab: TrainListTab) -> Bool {
        switch tab {
        case .departures:
            guard stationMessage.atd == nil else {
                return false
            }

            return isScheduledTimeVisible(stationMessage.std)
                && (stationMessage.std != nil || stationMessage.etd != nil)
        case .arrivals:
            guard stationMessage.ata == nil else {
                return false
            }

            return isScheduledTimeVisible(stationMessage.sta)
                && (stationMessage.sta != nil || stationMessage.eta != nil)
        }
    }

    private func isScheduledTimeVisible(_ scheduledTime: Date?) -> Bool {
        guard let scheduledTime else {
            return true
        }

        return scheduledTime >= AppTime.now.addingTimeInterval(-5 * 60)
    }

    private func compare(lhs: StationMessage, rhs: StationMessage, tab: TrainListTab) -> Bool {
        let lhsDate = sortDate(for: lhs, tab: tab) ?? .distantFuture
        let rhsDate = sortDate(for: rhs, tab: tab) ?? .distantFuture

        if lhsDate == rhsDate {
            return lhs.trainNo.localizedStandardCompare(rhs.trainNo) == .orderedAscending
        }

        return lhsDate < rhsDate
    }

    private func baseMessages(for tab: TrainListTab) -> [StationMessage] {
        Array(stationMessages
            .filter { isVisible($0, tab: tab) }
            .sorted { lhs, rhs in
                compare(lhs: lhs, rhs: rhs, tab: tab)
            }
            .prefix(maxUpcomingMessages))
    }

    private func sortDate(for stationMessage: StationMessage, tab: TrainListTab) -> Date? {
        switch tab {
        case .departures:
            return stationMessage.etd ?? stationMessage.std ?? stationMessage.atd
        case .arrivals:
            return stationMessage.eta ?? stationMessage.sta ?? stationMessage.ata
        }
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

    private func normalizedStationCode(for value: String?) -> String {
        value?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() ?? ""
    }

    private func stationMatchCandidates(from rawValues: [String?]) -> Set<String> {
        var candidates: Set<String> = []

        for rawValue in rawValues {
            let normalizedValue = normalizedStationCode(for: rawValue)
            if !normalizedValue.isEmpty {
                candidates.insert(normalizedValue)
            }

            let remappedValue = normalizedStationCode(for: CommonService.remappedTrainMessageStationCode(for: rawValue))
            if !remappedValue.isEmpty {
                candidates.insert(remappedValue)
            }
        }

        return candidates
    }

    private func matchesFilters(_ stationMessage: StationMessage, lineNumberFilters: Set<String>, trackFilters: Set<String>) -> Bool {
        TrainListFilterMatching.matches(
            lineValue: lineNumberOptionValue(for: stationMessage),
            trackValue: trackFilterValue(for: stationMessage),
            lineNumberFilters: lineNumberFilters,
            trackFilters: trackFilters
        )
    }

    /// The line number option is only resolved from actual line-number data (primary or fallback
    /// train message lookup). The train number is intentionally excluded here so it never appears
    /// as a selectable "line" option when no real line number is available for a train.
    private func lineNumberOptionValue(for stationMessage: StationMessage) -> String? {
        normalizedText(trainDetail(for: stationMessage)?.lineNumber) ?? fallbackLineNumber(for: stationMessage)
    }

    private func fallbackLineNumber(for stationMessage: StationMessage) -> String? {
        trainMessagesByKey.values
            .first(where: { trainMessage in
                trainMessage.countryCode.localizedCaseInsensitiveCompare(stationMessage.countryCode) == .orderedSame
                    && trainMessage.trainNo.localizedCaseInsensitiveCompare(stationMessage.trainNo) == .orderedSame
            })
            .flatMap { normalizedText($0.lineNumber) }
    }

    private func trackFilterValue(for stationMessage: StationMessage) -> String? {
        normalizedText(trackText(for: stationMessage))
    }

    private func uniqueSortedValues(from values: [String]) -> [String] {
        var seen: Set<String> = []
        var ordered: [String] = []

        for value in values {
            let key = value.uppercased()
            if seen.insert(key).inserted {
                ordered.append(value)
            }
        }

        return ordered.sorted { lhs, rhs in
            lhs.localizedStandardCompare(rhs) == .orderedAscending
        }
    }

}
