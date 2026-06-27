import CoreLocation
import Observation
import SwiftUI

struct TrainsTabView: View {
    @State private var favoritesStore = TrainStationFavoritesStore.shared
    @State private var lastUsedStore = TrainStationLastUsedStore.shared
    @State private var isTrainListPresented = false
    @State private var selectedStation: TraseStation?
    @State private var activeSwipeStationID: UUID?
    @State private var searchText = ""
    @State private var viewModel = TrainsTabViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.stations.isEmpty {
                    ProgressView("Laster stasjoner...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = viewModel.errorMessage, viewModel.stations.isEmpty {
                    ContentUnavailableView(
                        "Kunne ikke hente stasjoner",
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if shouldShowDropdown {
                    searchResults
                } else {
                    stationSections
                }
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle(tabGreetingTitle)
            .searchable(text: $searchText, prompt: "Søk etter stasjon")
            .navigationDestination(isPresented: $isTrainListPresented) {
                if let selectedStation {
                    TrainListView(station: selectedStation)
                }
            }
        }
        .task {
            await viewModel.start()
        }
        .onChange(of: favoritesStore.stations.map(\.storageKey)) { _, _ in
            viewModel.refreshNearestStations()
        }
        .onChange(of: searchText) { _, newValue in
            viewModel.updateSearchText(newValue)
        }
    }

    private var shouldShowDropdown: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var favoriteStationKeys: Set<String> {
        Set(favoritesStore.stations.map(\.storageKey))
    }

    private var recentStationsExcludingFavorites: [TraseStation] {
        lastUsedStore.stations.filter { !favoriteStationKeys.contains($0.storageKey) }
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

    private var stationSections: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if !favoritesStore.stations.isEmpty {
                    stationSection(
                        title: "Favoritter",
                        systemImage: "star.fill",
                        stations: favoritesStore.stations,
                        tint: .yellow,
                        bullet: .favorite,
                        onDeleteStation: { station in
                            favoritesStore.remove(station)
                        }
                    )
                }

                if !viewModel.nearestStations.isEmpty {
                    stationSection(
                        title: "Nærmeste",
                        systemImage: "location.fill",
                        stations: viewModel.nearestStations,
                        tint: Color.accentColor,
                        bullet: .nearest
                    )
                }

                if !recentStationsExcludingFavorites.isEmpty {
                    recentStationsSection
                }

                if viewModel.nearestStations.isEmpty && favoritesStore.stations.isEmpty && recentStationsExcludingFavorites.isEmpty {
                    ContentUnavailableView(
                        "Velg en stasjon",
                        systemImage: "tram.fill.tunnel",
                        description: Text("Søk etter en stasjon for å åpne toglisten.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 240)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 12)
            .appReadableContentWidth()
        }
        .scrollIndicators(.hidden)
    }

    private func stationSection(
        title: String,
        systemImage: String,
        stations: [TraseStation],
        tint: Color,
        bullet: StationBulletStyle,
        onDeleteStation: ((TraseStation) -> Void)? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: title, systemImage: systemImage, tint: tint)

            stationList(stations, bullet: bullet, onDeleteStation: onDeleteStation)
        }
    }

    private var recentStationsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "Sist brukte", systemImage: "clock.arrow.circlepath", tint: .orange)

            stationList(recentStationsExcludingFavorites, bullet: .recent) { station in
                lastUsedStore.remove(station)
            }

            Button {
                lastUsedStore.clear()
            } label: {
                Text("Tøm sist brukte")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.accentColor.opacity(0.10), in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(Color.accentColor.opacity(0.30), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 6)
        }
    }

    private func stationList(
        _ stations: [TraseStation],
        bullet: StationBulletStyle,
        onDeleteStation: ((TraseStation) -> Void)? = nil
    ) -> some View {
        VStack(spacing: 0) {
            stationDivider

            ForEach(Array(stations.enumerated()), id: \.element.id) { index, station in
                if let onDeleteStation {
                    SwipeDeleteIconRow(
                        rowID: station.id,
                        activeRowID: $activeSwipeStationID,
                        onTap: {
                            selectStation(station)
                        },
                        onDelete: {
                            onDeleteStation(station)
                        }
                    ) {
                        stationTile(station, bullet: bullet)
                    }
                } else {
                    stationSelectionButton(station, bullet: bullet)
                }

                if index < stations.count - 1 {
                    stationDivider
                }
            }

            stationDivider
        }
    }

    private var stationDivider: some View {
        Rectangle()
            .fill(AppTheme.border)
            .frame(height: 1)
    }

    private func stationSelectionButton(_ station: TraseStation, bullet: StationBulletStyle) -> some View {
        Button {
            activeSwipeStationID = nil
            selectStation(station)
        } label: {
            stationTile(station, bullet: bullet)
        }
        .buttonStyle(.plain)
    }

    private func sectionHeader(title: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 9) {
            Image(systemName: systemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)
                .background(tint.opacity(0.12), in: Circle())

            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)

            Spacer(minLength: 0)
        }
    }

    private func stationTile(_ station: TraseStation, bullet: StationBulletStyle) -> some View {
        HStack(spacing: 12) {
            stationBullet(bullet)

            VStack(alignment: .leading, spacing: 3) {
                Text(station.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let distanceText = viewModel.distanceText(for: station) {
                    Text(distanceText)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.leading, 24)
        .padding(.trailing, 4)
        .padding(.vertical, viewModel.distanceText(for: station) == nil ? 10 : 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func selectStation(_ station: TraseStation) {
        lastUsedStore.record(station)
        selectedStation = station
        isTrainListPresented = true
    }

    private var searchResults: some View {
        ScrollView {
            stationDropdown
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 12)
                .appReadableContentWidth()
        }
        .scrollIndicators(.hidden)
    }

    private var stationDropdown: some View {
        VStack(alignment: .leading, spacing: 0) {
            if viewModel.visibleStations.isEmpty {
                Text("Ingen treff")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
            } else {
                ForEach(Array(viewModel.visibleStations.enumerated()), id: \.element.id) { index, station in
                    Button {
                        selectStation(station)
                    } label: {
                        stationRow(station)
                    }
                    .buttonStyle(.plain)

                    if index < viewModel.visibleStations.count - 1 {
                        Rectangle()
                            .fill(AppTheme.border)
                            .frame(height: 1)
                            .padding(.leading, 14)
                    }
                }
            }
        }
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.border, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.05), radius: 10, y: 4)
    }

    private func stationRow(_ station: TraseStation) -> some View {
        HStack(alignment: .center, spacing: 10) {
            dropdownCountryFlagBadge(for: station)

            VStack(alignment: .leading, spacing: 3) {
                Text(station.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let distanceText = viewModel.distanceText(for: station) {
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
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func dropdownCountryFlagBadge(for station: TraseStation) -> some View {
        switch station.countryCode.uppercased() {
        case "NO":
            TrainsTabDropdownNorwayFlagBadge()
        case "SE":
            TrainsTabDropdownSwedenFlagBadge()
        default:
            Image(systemName: "tram.fill.tunnel")
                .font(.headline)
                .foregroundStyle(Color.accentColor)
                .frame(width: 42, height: 28)
                .background(AppTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    @ViewBuilder
    private func stationBullet(_ style: StationBulletStyle) -> some View {
        switch style {
        case .nearest:
            Circle()
                .fill(Color.accentColor)
                .frame(width: 10, height: 10)
        case .favorite:
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.yellow)
                .frame(width: 10, height: 10)
                .rotationEffect(.degrees(45))
                .frame(width: 14, height: 14)
        case .recent:
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.orange)
                .frame(width: 10, height: 10)
        }
    }
}

private enum StationBulletStyle {
    case nearest
    case favorite
    case recent
}

private struct SwipeDeleteIconRow<Content: View>: View {
    let rowID: UUID
    @Binding var activeRowID: UUID?
    let onTap: () -> Void
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
                .onTapGesture {
                    handleTap()
                }
                .gesture(dragGesture)
                .animation(.spring(response: 0.23, dampingFraction: 0.86), value: offsetX)
        }
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
        DragGesture(minimumDistance: 10)
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
        guard activeID != rowID else {
            return
        }

        offsetX = 0
    }

    private func handleTap() {
        if offsetX < 0 {
            activeRowID = nil
            offsetX = 0
        } else {
            activeRowID = nil
            onTap()
        }
    }
}

private struct TrainsTabDropdownNorwayFlagBadge: View {
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

private struct TrainsTabDropdownSwedenFlagBadge: View {
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
private final class TrainsTabViewModel {
    private(set) var nearestStations: [TraseStation] = []
    private(set) var stations: [TraseStation] = []
    private(set) var visibleStations: [TraseStation] = []
    var errorMessage: String?
    var isLoading = false

    private let service: SignalRService
    private let locationManager: TrainsTabLocationManager
    private var currentLocation: CLLocation?
    private var hasStarted = false
    private var searchText = ""
    private let nearestStationLimit = 3
    private let visibleStationLimit = 6

    init() {
        self.service = SignalRService()
        self.locationManager = TrainsTabLocationManager()
        configureBindings()
    }

    private func configureBindings() {
        locationManager.onLocationUpdate = { [weak self] location in
            guard let self else {
                return
            }

            self.currentLocation = location
            self.updateNearestStations()
        }

        service.onStations = { [weak self] stations in
            guard let self else {
                return
            }

            self.stations = stations.sortedByDisplayName()
            self.applySearch()
            self.updateNearestStations()
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

    func start() async {
        guard !hasStarted else {
            return
        }

        hasStarted = true
        isLoading = true
        locationManager.start()
        await service.start()
        await service.requestStations()
    }

    func updateSearchText(_ text: String) {
        searchText = text
        applySearch()
    }

    func refreshNearestStations() {
        updateNearestStations()
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

    private func applySearch() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty else {
            visibleStations = []
            return
        }

        visibleStations = stations
            .filter { station in
                station.name.localizedCaseInsensitiveContains(query)
                    || station.shortName.localizedCaseInsensitiveContains(query)
                    || (station.plcCode?.localizedCaseInsensitiveContains(query) ?? false)
            }
            .prefix(visibleStationLimit)
            .map { $0 }
    }

    private func updateNearestStations() {
        guard let currentLocation else {
            nearestStations = []
            return
        }

        let favoriteStationKeys = Set(TrainStationFavoritesStore.shared.stations.map(\.storageKey))

        nearestStations = stations
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
            .prefix(nearestStationLimit)
            .map(\.station)
    }
}

@MainActor
private final class TrainsTabLocationManager: NSObject, CLLocationManagerDelegate {
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


private extension Array where Element == TraseStation {
    func sortedByDisplayName() -> [TraseStation] {
        sorted { lhs, rhs in
            lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }
}

extension TraseStation {
    var storageKey: String {
        let countryCode = countryCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let shortName = shortName.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return "\(countryCode)::\(shortName)"
    }
}
