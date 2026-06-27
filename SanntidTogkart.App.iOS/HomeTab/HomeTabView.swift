import CoreLocation
import Observation
import SwiftUI

struct HomeTabView: View {
    @State private var favoritesStore = TrainStationFavoritesStore.shared
    @State private var lastUsedStore = TrainStationLastUsedStore.shared
    @State private var isTrainListPresented = false
    @State private var selectedStation: TraseStation?
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
        }
        .task {
            viewModel.start()
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
            sectionHeader(title: "Favoritter", systemImage: "star.fill", tint: .yellow)
            stationList(favoritesStore.stations)
        }
    }

    private func stationList(_ stations: [TraseStation]) -> some View {
        VStack(spacing: 0) {
            stationDivider

            ForEach(Array(stations.enumerated()), id: \.element.id) { index, station in
                SwipeDeleteIconRow(
                    rowID: station.id,
                    activeRowID: $activeSwipeStationID,
                    onTap: {
                        selectStation(station)
                    },
                    onDelete: {
                        favoritesStore.remove(station)
                    }
                ) {
                    stationTile(station)
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

    private func stationTile(_ station: TraseStation) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.yellow)
                .frame(width: 10, height: 10)
                .rotationEffect(.degrees(45))
                .frame(width: 14, height: 14)

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
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.leading, 24)
        .padding(.trailing, 4)
        .padding(.vertical, viewModel.distanceText(for: station) == nil ? 10 : 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func selectStation(_ station: TraseStation) {
        activeSwipeStationID = nil
        lastUsedStore.record(station)
        selectedStation = station
        isTrainListPresented = true
    }

    @ViewBuilder
    private func dropdownCountryFlagBadge(for station: TraseStation) -> some View {
        switch station.countryCode.uppercased() {
        case "NO":
            HomeTabDropdownNorwayFlagBadge()
        case "SE":
            HomeTabDropdownSwedenFlagBadge()
        default:
            Image(systemName: "tram.fill.tunnel")
                .font(.headline)
                .foregroundStyle(Color.accentColor)
                .frame(width: 42, height: 28)
                .background(AppTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 8))
        }
    }
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
                .simultaneousGesture(dragGesture)
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

@MainActor
@Observable
private final class HomeTabViewModel {
    private(set) var currentLocation: CLLocation?

    private let locationManager: HomeTabLocationManager
    private var hasStarted = false

    init() {
        self.locationManager = HomeTabLocationManager()
        configureBindings()
    }

    private func configureBindings() {
        locationManager.onLocationUpdate = { [weak self] location in
            self?.currentLocation = location
        }
    }

    func start() {
        guard !hasStarted else {
            return
        }

        hasStarted = true
        locationManager.start()
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
