import CoreLocation
import MapKit
import Observation
import SwiftUI
import UIKit

struct TrainMapTabView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL
    @State private var navigationCenter = AppNavigationCenter.shared
    @State private var connectionCenter = SignalRConnectionCenter.shared
    @State private var locationManager = TrainMapLocationManager()
    @State private var viewModel = TrainMapTabViewModel()
    @State private var isZoomedOut = false
    @State private var isCountryZoomedOut = false
    @State private var isTrainListPresented = false
    @State private var isStatsPresented = false
    @State private var isStatusPresented = false
    @State private var isMapModePresented = false
    @State private var isLocationPermissionAlertPresented = false
    @State private var showsStationMarkers = true
    @State private var showsStationMarkerLabels = true
    @State private var showsTrainMarkers = true
    @State private var selectedStationID: UUID?
    @State private var isSelectedTrainCardVisible = true
    @State private var trainListDragOffset: CGFloat = 0
    @State private var statsDragOffset: CGFloat = 0
    @State private var statusDragOffset: CGFloat = 0
    @State private var mapModeDragOffset: CGFloat = 0
    @State private var mapMode: TrainMapMode = .standard
    @State private var trainForStationsView: TrainMessage?
    @State private var isTrainStationsViewPresented = false
    @State private var pendingStationSelectionRequest: StationMapSelectionRequest?
    @State private var presentedTrainListEntries: [TrainListEntry] = []
    @State private var visibleRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 59.9139, longitude: 10.7522),
        span: MKCoordinateSpan(latitudeDelta: 0.18, longitudeDelta: 0.18)
    )
    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 59.9139, longitude: 10.7522),
            span: MKCoordinateSpan(latitudeDelta: 0.18, longitudeDelta: 0.18)
        )
    )

    var body: some View {
        NavigationStack {
            Map(position: $position) {
                routeOverlayContent
                currentLocationContent
                stationAnnotationContent
                trainAnnotationContent
            }
            .mapStyle(mapMode.mapStyle)
            .mapControls {
                MapCompass()
                MapScaleView()
                MapPitchToggle()
            }
            .onMapCameraChange { context in
                let region = expandedRegion(for: context.region)
                let span = context.region.span
                visibleRegion = region
                isZoomedOut = span.latitudeDelta > 1.6 || span.longitudeDelta > 1.6
                isCountryZoomedOut = span.latitudeDelta > 8.5 || span.longitudeDelta > 8.5
            }
            .overlay(alignment: .topLeading) {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
                        .padding()
                }
            }
            .overlay(alignment: .topTrailing) {
                if viewModel.isLoading {
                    ProgressView()
                        .padding(12)
                        .background(.thinMaterial, in: Circle())
                        .padding()
                }
            }
            .overlay(alignment: .top) {
                if let selectedTrain {
                    if isSelectedTrainCardVisible {
                        SelectedTrainCard(
                            train: selectedTrain,
                            routeText: viewModel.displayRoute(for: selectedTrain),
                            distanceText: viewModel.selectedTrainRemainingDistanceText,
                            totalDistanceText: viewModel.selectedTrainTotalRouteDistanceText,
                            passedDistanceText: viewModel.selectedTrainPassedDistanceText,
                            departureTimeText: viewModel.selectedTrainDepartureTimeText,
                            arrivalTimeText: viewModel.selectedTrainArrivalTimeText,
                            travelTimeText: viewModel.selectedTrainTravelTimeText,
                            remainingTimeText: viewModel.selectedTrainRemainingTimeText,
                            nextStationText: viewModel.selectedTrainNextStationText,
                            nextStationDetailText: viewModel.selectedTrainNextStationDetailText,
                            progress: viewModel.selectedTrainRouteProgress,
                            onOpenRoute: {
                                trainForStationsView = selectedTrain
                                isTrainStationsViewPresented = true
                            },
                            onCollapse: {
                                isSelectedTrainCardVisible = false
                            },
                            onClear: clearSelectedTrain
                        )
                        .padding(.top, 18)
                        .padding(.horizontal, 16)
                    } else {
                        CollapsedSelectedTrainCard(
                            train: selectedTrain,
                            routeText: viewModel.displayRoute(for: selectedTrain),
                            onExpand: {
                                isSelectedTrainCardVisible = true
                            },
                            onClear: clearSelectedTrain
                        )
                        .padding(.top, 18)
                        .padding(.horizontal, 16)
                    }
                } else if let selectedStation {
                    SelectedStationCard(
                        station: selectedStation,
                        distanceText: distanceText(for: selectedStation)
                    ) {
                        selectedStationID = nil
                    }
                    .padding(.top, 18)
                    .padding(.horizontal, 16)
                }
            }
            .overlay {
                if isTrainListPresented || isStatsPresented || isStatusPresented || isMapModePresented {
                    Color.black.opacity(0.001)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if isTrainListPresented {
                                dismissTrainList()
                            }
                            if isStatsPresented {
                                dismissStats()
                            }
                            if isStatusPresented {
                                dismissStatus()
                            }
                            if isMapModePresented {
                                dismissMapMode()
                            }
                        }
                }
            }
            .overlay(alignment: .bottom) {
                if isTrainListPresented {
                    trainListSheet
                        .padding(.horizontal, 16)
                        .padding(.bottom, 92)
                        .offset(y: max(0, trainListDragOffset))
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        ))
                        .gesture(
                            DragGesture(minimumDistance: 8)
                                .onChanged { value in
                                    guard value.translation.height > 0 else {
                                        trainListDragOffset = 0
                                        return
                                    }

                                    trainListDragOffset = value.translation.height
                                }
                                .onEnded { value in
                                    if value.translation.height > 120 || value.predictedEndTranslation.height > 180 {
                                        dismissTrainList()
                                    } else {
                                        withAnimation(.easeOut(duration: 0.2)) {
                                            trainListDragOffset = 0
                                        }
                                    }
                                }
                        )
                        .zIndex(2)
                }
            }
            .overlay(alignment: .bottom) {
                if isStatsPresented && !isTrainListPresented {
                    mapStatisticsPanel
                        .padding(.horizontal, 16)
                        .padding(.bottom, 92)
                        .offset(y: max(0, statsDragOffset))
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        ))
                        .gesture(
                            DragGesture(minimumDistance: 8)
                                .onChanged { value in
                                    guard value.translation.height > 0 else {
                                        statsDragOffset = 0
                                        return
                                    }

                                    statsDragOffset = value.translation.height
                                }
                                .onEnded { value in
                                    if value.translation.height > 120 || value.predictedEndTranslation.height > 180 {
                                        dismissStats()
                                    } else {
                                        withAnimation(.easeOut(duration: 0.2)) {
                                            statsDragOffset = 0
                                        }
                                    }
                                }
                        )
                        .zIndex(2)
                }
            }
            .overlay(alignment: .bottom) {
                if isStatusPresented && !isTrainListPresented && !isStatsPresented {
                    connectionStatusPanel
                        .padding(.horizontal, 16)
                        .padding(.bottom, 92)
                        .offset(y: max(0, statusDragOffset))
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        ))
                        .gesture(
                            DragGesture(minimumDistance: 8)
                                .onChanged { value in
                                    guard value.translation.height > 0 else {
                                        statusDragOffset = 0
                                        return
                                    }

                                    statusDragOffset = value.translation.height
                                }
                                .onEnded { value in
                                    if value.translation.height > 120 || value.predictedEndTranslation.height > 180 {
                                        dismissStatus()
                                    } else {
                                        withAnimation(.easeOut(duration: 0.2)) {
                                            statusDragOffset = 0
                                        }
                                    }
                                }
                        )
                        .zIndex(2)
                }
            }
            .overlay(alignment: .bottom) {
                if isMapModePresented && !isTrainListPresented && !isStatsPresented && !isStatusPresented {
                    mapModePanel
                        .padding(.horizontal, 16)
                        .padding(.bottom, 92)
                        .offset(y: max(0, mapModeDragOffset))
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        ))
                        .gesture(
                            DragGesture(minimumDistance: 8)
                                .onChanged { value in
                                    guard value.translation.height > 0 else {
                                        mapModeDragOffset = 0
                                        return
                                    }

                                    mapModeDragOffset = value.translation.height
                                }
                                .onEnded { value in
                                    if value.translation.height > 120 || value.predictedEndTranslation.height > 180 {
                                        dismissMapMode()
                                    } else {
                                        withAnimation(.easeOut(duration: 0.2)) {
                                            mapModeDragOffset = 0
                                        }
                                    }
                                }
                        )
                        .zIndex(2)
                }
            }
            .overlay(alignment: .bottom) {
                if !isTrainListPresented && !isStatsPresented && !isStatusPresented && !isMapModePresented {
                    bottomControlBar
                        .padding(.horizontal, 16)
                        .padding(.bottom, 96)
                }
            }
            .task {
                await viewModel.start()
            }
            .onChange(of: navigationCenter.stationMapSelectionRequest) { _, request in
                guard let request else {
                    return
                }

                guard navigationCenter.selectedDashboardTab == .map else {
                    pendingStationSelectionRequest = request
                    return
                }

                revealStationOnMap(request)
            }
            .onChange(of: navigationCenter.selectedDashboardTab) { _, selectedTab in
                guard
                    selectedTab == .map,
                    let pendingStationSelectionRequest
                else {
                    return
                }

                revealStationOnMap(pendingStationSelectionRequest)
            }
            .onChange(of: viewModel.stations.count) { _, _ in
                guard let pendingStationSelectionRequest else {
                    return
                }

                revealStationOnMap(pendingStationSelectionRequest)
            }
            .refreshable {
                guard !isTrainListPresented, !isStatsPresented, !isStatusPresented, !isMapModePresented else {
                    return
                }
                await viewModel.refresh()
            }
            .ignoresSafeArea(edges: .bottom)
            .navigationDestination(isPresented: $isTrainStationsViewPresented) {
                if let trainForStationsView {
                    TrainStationsView(trainMessage: trainForStationsView, title: "Togrute")
                }
            }
            .alert("Lokasjonstilgang kreves", isPresented: $isLocationPermissionAlertPresented) {
                Button("Avbryt", role: .cancel) {}
                Button("Åpne innstillinger") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else {
                        return
                    }

                    openURL(url)
                }
            } message: {
                Text("Gi tilgang til posisjon i Innstillinger for å vise din nåværende posisjon og avstand til stasjoner.")
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var renderedStations: [TraseStation] {
        viewModel.stationsInVisibleRegion(visibleRegion, limit: isZoomedOut ? 120 : 300)
    }

    private var renderedTrains: [TrainMessage] {
        viewModel.trainsInVisibleRegion(visibleRegion, limit: isZoomedOut ? 250 : 150)
    }

    @MapContentBuilder
    private var routeOverlayContent: some MapContent {
        if viewModel.selectedTrainRouteCoordinates.count > 1 {
            MapPolyline(coordinates: viewModel.selectedTrainRouteCoordinates)
                .stroke(Color.white.opacity(0.8), lineWidth: 8)

            MapPolyline(coordinates: viewModel.selectedTrainRouteCoordinates)
                .stroke(Color.accentColor, lineWidth: 4)

            if let routeStartCoordinate = viewModel.selectedTrainRouteCoordinates.first {
                Annotation("Rutestart", coordinate: routeStartCoordinate) {
                    RouteStartAnnotation()
                }
            }
        }

        if viewModel.selectedTrainFutureRouteCoordinates.count > 1 {
            MapPolyline(coordinates: viewModel.selectedTrainFutureRouteCoordinates)
                .stroke(
                    Color.accentColor,
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round, dash: [1, 3])
                )
        }
    }

    @MapContentBuilder
    private var currentLocationContent: some MapContent {
        if let currentLocation = locationManager.currentLocation {
            Annotation("Nåværende posisjon", coordinate: currentLocation.clCoordinate) {
                CurrentLocationAnnotation()
            }
        }
    }

    @MapContentBuilder
    private var stationAnnotationContent: some MapContent {
        if showsStationMarkers && !isTrainListPresented {
            ForEach(renderedStations) { station in
                Annotation(showsStationMarkerLabels ? stationAnnotationTitle(for: station) : "", coordinate: station.coordinate) {
                    Button {
                        toggleSelection(for: station)
                    } label: {
                        if isZoomedOut {
                            StationMapDotAnnotation()
                        } else {
                            StationMapAnnotation(
                                isHighlighted: station.id == selectedStationID
                            )
                        }
                    }
                    .buttonStyle(.plain)
                    .zIndex(1)
                }
            }
        }
    }

    private func stationAnnotationTitle(for station: TraseStation) -> String {
        [station.name, station.shortName, station.plcCode]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " • ")
    }

    @MapContentBuilder
    private var trainAnnotationContent: some MapContent {
        if showsTrainMarkers && !isTrainListPresented {
            ForEach(renderedTrains) { train in
                if let coordinate = viewModel.mapCoordinate(for: train) {
                    Annotation(viewModel.displayLineNumber(for: train), coordinate: coordinate) {
                        Button {
                            toggleSelection(for: train)
                        } label: {
                            if isCountryZoomedOut {
                                TrainMapDotAnnotation(
                                    trainType: train.trainType,
                                    isHighlighted: train.id == viewModel.selectedTrainMessageID
                                )
                            } else {
                                TrainMapAnnotation(
                                    trainType: train.trainType,
                                    isHighlighted: train.id == viewModel.selectedTrainMessageID
                                )
                            }
                        }
                        .buttonStyle(.plain)
                        .zIndex(2)
                    }
                }
            }
        }
    }

    private var selectedTrain: TrainMessage? {
        viewModel.selectedTrain
    }

    private var selectedStation: TraseStation? {
        guard let selectedStationID else {
            return nil
        }

        return viewModel.stations.first(where: { $0.id == selectedStationID })
    }

    private func distanceText(for station: TraseStation) -> String? {
        guard
            let currentLocation = locationManager.currentLocation,
            let latitude = station.latitude,
            let longitude = station.longitude
        else {
            return nil
        }

        let stationLocation = CLLocation(latitude: latitude, longitude: longitude)
        let userLocation = CLLocation(
            latitude: currentLocation.latitude,
            longitude: currentLocation.longitude
        )
        let distance = userLocation.distance(from: stationLocation)

        if distance < 1000 {
            return "\(Int(distance.rounded())) m"
        }

        return String(format: "%.1f km", distance / 1000)
    }

    private var markerTogglePanel: some View {
        HStack(spacing: 6) {
            markerToggle(
                systemImage: "building.columns.fill",
                isOn: $showsStationMarkers
            )

            markerToggle(
                systemImage: "textformat",
                isOn: $showsStationMarkerLabels
            )
            .disabled(!showsStationMarkers)
            .opacity(showsStationMarkers ? 1 : 0.45)

            markerToggle(
                systemImage: "tram.fill",
                isOn: $showsTrainMarkers
            )

        }
    }

    private var bottomControlBar: some View {
        VStack(spacing: 10) {
            markerTogglePanel

            HStack(spacing: 10) {
                currentLocationButton
                mapModeButton
                statusButton
                statsButton
                trainListButton
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(bottomControlBarBackgroundColor, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.primary.opacity(0.10), lineWidth: 0.8)
        }
        .shadow(color: Color.black.opacity(0.08), radius: 10, y: 4)
    }

    private var bottomControlBarBackgroundColor: Color {
        if colorScheme == .dark {
            return Color.white.opacity(0.18)
        }

        return Color(.systemBackground).opacity(0.52)
    }

    private var highlightedMapControlIconColor: Color {
        colorScheme == .dark ? .white : Color.accentColor
    }

    private var neutralMapControlIconColor: Color {
        colorScheme == .dark ? .white : .primary
    }

    private var mapModeButton: some View {
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                isMapModePresented.toggle()
                mapModeDragOffset = 0
            }
        } label: {
            Image(systemName: mapMode.systemImage)
                .font(.headline)
                .foregroundStyle(highlightedMapControlIconColor)
                .frame(width: 48, height: 48)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Velg kartvisning")
    }

    private var statsButton: some View {
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                isStatsPresented.toggle()
                statsDragOffset = 0
            }
        } label: {
            Image(systemName: isStatsPresented ? "chart.bar.xaxis.circle.fill" : "chart.bar.xaxis")
                .font(.headline)
                .foregroundStyle(highlightedMapControlIconColor)
                .frame(width: 48, height: 48)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Vis statistikk")
    }

    private var statusButton: some View {
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                isStatusPresented.toggle()
                statusDragOffset = 0
            }
        } label: {
            ZStack {
                ConnectionStatusDot(state: connectionCenter.state)
                    .frame(width: 48, height: 48)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(connectionCenter.accessibilityStatusText)
    }

    private func markerToggle(systemImage: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.primary)

            Toggle("", isOn: Binding(
                get: { isOn.wrappedValue },
                set: { newValue in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isOn.wrappedValue = newValue
                    }
                }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .tint(.accentColor)
            .scaleEffect(0.72)
            .frame(width: 42)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
    }

    private var trainListButton: some View {
        Button {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                if !isTrainListPresented {
                    presentedTrainListEntries = makeTrainListEntries()
                }
                isTrainListPresented.toggle()
            }
        } label: {
            Image(systemName: "list.bullet")
                .font(.headline)
                .foregroundStyle(highlightedMapControlIconColor)
                .frame(width: 48, height: 48)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Apne togliste")
    }

    private var currentLocationButton: some View {
        Button {
            switch locationManager.authorizationStatus {
            case .denied, .restricted:
                isLocationPermissionAlertPresented = true
            default:
                locationManager.requestCurrentLocation()
            }
        } label: {
            Image(systemName: "location.fill")
                .font(.headline)
                .foregroundStyle(locationManager.hasLocationAccess ? highlightedMapControlIconColor : neutralMapControlIconColor)
                .frame(width: 48, height: 48)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Gå til nåværende posisjon")
    }

    private var trainListSheet: some View {
        TrainListSheet(
            entries: presentedTrainListEntries,
            onRefresh: {
                presentedTrainListEntries = makeTrainListEntries()
            },
            onSelectTrain: { train in
                selectTrain(train)
            },
            onClearSelection: {
                viewModel.clearSelection()
            }
        )
    }

    private func expandedRegion(for region: MKCoordinateRegion) -> MKCoordinateRegion {
        MKCoordinateRegion(
            center: region.center,
            span: MKCoordinateSpan(
                latitudeDelta: region.span.latitudeDelta * 1.2,
                longitudeDelta: region.span.longitudeDelta * 1.2
            )
        )
    }

    private func selectTrain(_ train: TrainMessage) {
        dismissTrainList()
        isSelectedTrainCardVisible = true

        if
            let coordinate = viewModel.mapCoordinate(for: train),
            !visibleRegion.contains(coordinate: coordinate)
        {
            withAnimation(.easeInOut(duration: 0.35)) {
                position = .region(
                    MKCoordinateRegion(
                        center: coordinate,
                        span: visibleRegion.span
                    )
                )
            }
        }

        Task {
            await viewModel.selectTrain(train)
        }
    }

    private func toggleSelection(for train: TrainMessage) {
        selectedStationID = nil

        if viewModel.selectedTrainMessageID == train.id {
            clearSelectedTrain()
            return
        }

        selectTrain(train)
    }

    private func clearSelectedTrain() {
        isSelectedTrainCardVisible = false
        viewModel.clearSelection()
    }

    private func toggleSelection(for station: TraseStation) {
        isSelectedTrainCardVisible = false
        viewModel.clearSelection()

        if selectedStationID == station.id {
            selectedStationID = nil
            return
        }

        selectedStationID = station.id
    }

    private func revealStationOnMap(_ request: StationMapSelectionRequest) {
        guard viewModel.stations.contains(where: { $0.id == request.stationID }) else {
            pendingStationSelectionRequest = request
            return
        }

        pendingStationSelectionRequest = nil
        isSelectedTrainCardVisible = false
        viewModel.clearSelection()
        selectedStationID = nil

        guard let latitude = request.latitude, let longitude = request.longitude else {
            selectedStationID = request.stationID
            return
        }

        withAnimation(.easeInOut(duration: 0.35)) {
            position = .region(
                MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                    span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)
                )
            )
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            guard pendingStationSelectionRequest == nil else {
                return
            }
            selectedStationID = request.stationID
        }
    }

    private func dismissTrainList() {
        withAnimation(.spring(response: 0.34, dampingFraction: 0.9)) {
            isTrainListPresented = false
            trainListDragOffset = 0
        }
        presentedTrainListEntries = []
    }

    private func makeTrainListEntries() -> [TrainListEntry] {
        viewModel.trainMessages.map { train in
            TrainListEntry(
                train: train,
                routeText: viewModel.displayRoute(for: train),
                searchTokens: viewModel.searchTokens(for: train),
                displayLineNumber: normalizedText(train.lineNumber),
                displayTrainNumber: viewModel.displayTrainNumber(for: train),
                displayCompany: normalizedText(viewModel.displayCompany(for: train)),
                trainType: normalizedText(train.trainType)
            )
        }
    }

    private func dismissStats() {
        withAnimation(.spring(response: 0.34, dampingFraction: 0.9)) {
            isStatsPresented = false
            statsDragOffset = 0
        }
    }

    private func dismissStatus() {
        withAnimation(.spring(response: 0.34, dampingFraction: 0.9)) {
            isStatusPresented = false
            statusDragOffset = 0
        }
    }

    private var mapStatisticsPanel: some View {
        MapStatisticsPanel(
            metrics: viewModel.metrics,
            totalLiveTrainCount: viewModel.totalLiveTrainCount,
            operatorCounts: Array(viewModel.operatorCounts.prefix(6)),
            trainTypeCounts: Array(viewModel.trainTypeCounts.prefix(6))
        )
    }

    private var connectionStatusPanel: some View {
        ConnectionStatusPanel(
            state: connectionCenter.state,
            details: connectionCenter.details,
            lastUpdated: connectionCenter.lastUpdated,
            handshake: connectionCenter.lastHandshake
        )
    }

    private var mapModePanel: some View {
        MapModePanel(selectedMode: mapMode) { mode in
            mapMode = mode
            dismissMapMode()
        }
    }

    private func dismissMapMode() {
        withAnimation(.spring(response: 0.34, dampingFraction: 0.9)) {
            isMapModePresented = false
            mapModeDragOffset = 0
        }
    }
}

private struct MapStatisticsPanel: View {
    let metrics: TrainMetrics?
    let totalLiveTrainCount: Int
    let operatorCounts: [OperatorTrainCount]
    let trainTypeCounts: [OperatorTrainCount]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Capsule()
                .fill(Color.secondary.opacity(0.35))
                .frame(width: 38, height: 5)
                .padding(.top, 8)
                .frame(maxWidth: .infinity)

            HStack(spacing: 8) {
                compactMetric(title: "Stasjoner", flag: "NO", value: metrics.map { "\($0.trainStationsCountNO)" } ?? "—")
                compactMetric(title: "Ruter", flag: "NO", value: metrics.map { "\($0.trainMessagesCountNO)" } ?? "—")
                compactMetric(title: "Stasjoner", flag: "SE", value: metrics.map { "\($0.trainStationsCountSE)" } ?? "—")
                compactMetric(title: "Ruter", flag: "SE", value: metrics.map { "\($0.trainMessagesCountSE)" } ?? "—")
            }

            compactHighlight(title: "Aktive tog", value: "\(totalLiveTrainCount)")

            statisticChipRow(title: "Operatører", items: operatorCounts)
            statisticChipRow(title: "Togtyper", items: trainTypeCounts)
        }
        .padding(12)
        .frame(maxWidth: 560, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.45), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.18), radius: 20, y: 10)
    }

    private func compactMetric(title: String, flag: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack(spacing: 6) {
                MapStatisticsCountryFlagBadge(countryCode: flag)

                Text(value)
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(AppTheme.surface.opacity(0.82), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        }
    }

    private func compactHighlight(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer(minLength: 8)

            Text(value)
                .font(.headline.monospacedDigit().weight(.bold))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            AppTheme.surface,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.accentColor.opacity(0.16), lineWidth: 1)
        }
    }

    private func statisticChipRow(title: String, items: [OperatorTrainCount]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(items) { item in
                        HStack(spacing: 6) {
                            Text(item.name)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.primary)
                                .lineLimit(1)

                            Text("\(item.count)")
                                .font(.caption.monospacedDigit().weight(.bold))
                                .foregroundStyle(Color.accentColor)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(AppTheme.surface.opacity(0.82), in: Capsule())
                        .overlay {
                            Capsule()
                                .stroke(AppTheme.border, lineWidth: 1)
                        }
                    }
                }
                .padding(.horizontal, 1)
            }
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        }
    }
}

private struct MapModePanel: View {
    let selectedMode: TrainMapMode
    let onSelectMode: (TrainMapMode) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Capsule()
                .fill(Color.secondary.opacity(0.35))
                .frame(width: 38, height: 5)
                .padding(.top, 8)
                .frame(maxWidth: .infinity)

            Text("Kartvisning")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)

            VStack(spacing: 8) {
                ForEach(TrainMapMode.allCases) { mode in
                    Button {
                        onSelectMode(mode)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: mode.systemImage)
                                .font(.headline)
                                .frame(width: 24)

                            Text(mode.title)
                                .font(.subheadline.weight(.medium))

                            Spacer(minLength: 8)

                            if mode == selectedMode {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .background(AppTheme.surface.opacity(0.82), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(mode == selectedMode ? Color.accentColor.opacity(0.35) : AppTheme.border, lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: 560, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.45), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.18), radius: 20, y: 10)
    }
}

private struct ConnectionStatusPanel: View {
    let state: ConnectionState
    let details: String
    let lastUpdated: Date?
    let handshake: SignalRHandshakeInfo?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Capsule()
                .fill(Color.secondary.opacity(0.35))
                .frame(width: 38, height: 5)
                .padding(.top, 8)
                .frame(maxWidth: .infinity)

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(state.description)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                }

                Spacer(minLength: 8)
            }

            if shouldShowDetails {
                infoRow(title: "Detaljer", value: details)
            }

            if let handshake {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        handshakeCard(title: "Melding", value: handshake.message)
                        handshakeCard(title: "Connection ID", value: handshake.connectionId)
                    }

                    handshakeCard(
                        title: "Tidspunkt",
                        value: handshake.timestamp.formatted(date: .abbreviated, time: .standard)
                    )
                }
            } else {
                Text("Venter på handshake-informasjon fra FeedHub.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: 560, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.45), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.18), radius: 20, y: 10)
    }

    private var shouldShowDetails: Bool {
        let normalizedDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedState = state.description.trimmingCharacters(in: .whitespacesAndNewlines)
        return !normalizedDetails.isEmpty && normalizedDetails != normalizedState
    }

    private func infoRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.footnote)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppTheme.surface.opacity(0.82), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        }
    }

    private func handshakeCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.footnote)
                .foregroundStyle(.primary)
                .lineLimit(title == "Connection ID" ? 2 : nil)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(AppTheme.surface.opacity(0.82), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        }
    }

}

private struct MapStatisticsCountryFlagBadge: View {
    let countryCode: String

    var body: some View {
        Group {
            switch countryCode.uppercased() {
            case "NO":
                MapStatisticsNorwayFlagBadge()
            case "SE":
                MapStatisticsSwedenFlagBadge()
            default:
                Rectangle()
                    .fill(AppTheme.elevatedSurface)
                    .frame(width: 18, height: 12)
                    .overlay {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(AppTheme.border, lineWidth: 1)
                    }
            }
        }
        .frame(width: 18, height: 12)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}

private struct MapStatisticsNorwayFlagBadge: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color(red: 0.73, green: 0.11, blue: 0.17))

            Rectangle()
                .fill(.white)
                .frame(width: 4)
                .offset(x: -4)

            Rectangle()
                .fill(.white)
                .frame(height: 4)

            Rectangle()
                .fill(Color(red: 0.0, green: 0.13, blue: 0.36))
                .frame(width: 2.4)
                .offset(x: -4)

            Rectangle()
                .fill(Color(red: 0.0, green: 0.13, blue: 0.36))
                .frame(height: 2.4)
        }
    }
}

private struct MapStatisticsSwedenFlagBadge: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color(red: 0.0, green: 0.32, blue: 0.61))

            Rectangle()
                .fill(Color(red: 0.98, green: 0.80, blue: 0.17))
                .frame(width: 3.4)
                .offset(x: -4)

            Rectangle()
                .fill(Color(red: 0.98, green: 0.80, blue: 0.17))
                .frame(height: 3.4)
        }
    }
}

private struct TrainListSheet: View {
    let entries: [TrainListEntry]
    let onRefresh: () -> Void
    let onSelectTrain: (TrainMessage) -> Void
    let onClearSelection: () -> Void

    @State private var searchText = ""
    @State private var lastRefreshedQuery = ""
    private let drawerContentHeightRatio: CGFloat = 0.5

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                Spacer(minLength: 0)

                VStack(spacing: 6) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.35))
                        .frame(width: 38, height: 5)
                        .padding(.top, 8)

                    searchField
                    summaryCard
                    content(drawerContentHeight: geometry.size.height * drawerContentHeightRatio)
                }
                .padding(12)
                .frame(maxWidth: 560)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26))
                .overlay {
                    RoundedRectangle(cornerRadius: 26)
                        .stroke(Color.white.opacity(0.45), lineWidth: 1)
                }
                .shadow(color: Color.black.opacity(0.16), radius: 20, y: 10)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .onChange(of: searchText) { _, newValue in
            let trimmedQuery = newValue.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !trimmedQuery.isEmpty else {
                lastRefreshedQuery = ""
                return
            }

            guard displayedTrainList.isEmpty, lastRefreshedQuery != trimmedQuery else {
                return
            }

            lastRefreshedQuery = trimmedQuery
            onRefresh()
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Sok etter tog eller linjenummer", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    lastRefreshedQuery = ""
                    onClearSelection()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(AppTheme.background)
        )
        .overlay {
            Capsule()
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        }
    }

    @ViewBuilder
    private func content(drawerContentHeight: CGFloat) -> some View {
        if !displayedTrainList.isEmpty {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(displayedTrainList.enumerated()), id: \.element.id) { index, entry in
                        trainListRow(entry)

                        if index < displayedTrainList.count - 1 {
                            Rectangle()
                                .fill(AppTheme.border)
                                .frame(height: 1)
                                .padding(.leading, 56)
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
            .refreshable {
                onRefresh()
            }
            .frame(height: drawerContentHeight)
        } else {
            VStack {
                Spacer()

                Text("Ingen tog funnet")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 18)

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .frame(height: drawerContentHeight, alignment: .center)
        }
    }

    private func trainListRow(_ entry: TrainListEntry) -> some View {
        return Button {
            onSelectTrain(entry.train)
        } label: {
            HStack(alignment: .center, spacing: 12) {
                TrainListCountryFlagBadge(countryCode: entry.train.countryCode)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        if let lineNumber = entry.displayLineNumber {
                            Text(lineNumber)
                                .font(.subheadline.monospacedDigit().weight(.semibold))
                                .foregroundStyle(.primary)

                            Text("•")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.primary.opacity(0.78))
                        }

                        Text(entry.displayTrainNumber)
                            .font(.subheadline.monospacedDigit().weight(.medium))
                            .foregroundStyle(.primary)

                        if let company = entry.displayCompany {
                            Text("•")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.primary.opacity(0.78))

                            Text(company)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.primary.opacity(0.78))
                                .lineLimit(1)

                            if let trainType = entry.trainType {
                                Text("•")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(.primary.opacity(0.78))

                                Text(trainType)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.primary.opacity(0.78))
                                    .lineLimit(1)
                            }
                        }

                        Spacer(minLength: 0)
                    }

                    Text(entry.routeText)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var summaryCard: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Togliste")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text("Live oversikt over aktive tog")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 3) {
                Text("\(displayedTrainList.count)")
                    .font(.title3.monospacedDigit().weight(.bold))
                    .foregroundStyle(.primary)

                Text("treff")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(AppTheme.surface)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.border, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.04), radius: 10, y: 4)
    }

    private var displayedTrainList: [TrainListEntry] {
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return entries
        }

        return entries.filter { entry in
            entry.searchTokens.contains { token in
                token.localizedCaseInsensitiveContains(trimmedQuery)
            }
        }
    }
}

private struct TrainListEntry: Identifiable {
    let train: TrainMessage
    let routeText: String
    let searchTokens: [String]
    let displayLineNumber: String?
    let displayTrainNumber: String
    let displayCompany: String?
    let trainType: String?

    var id: Int { train.id }
}

private extension TraseStation {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude ?? 0, longitude: longitude ?? 0)
    }

    var displayCoordinateText: String {
        guard let latitude, let longitude else {
            return "Ukjent"
        }

        return String(format: "%.5f, %.5f", latitude, longitude)
    }

    var displayTimestamp: String {
        guard let lastUpdated else {
            return "Ukjent"
        }

        return lastUpdated.formatted(
            .dateTime
                .year()
                .month(.twoDigits)
                .day(.twoDigits)
                .hour(.twoDigits(amPM: .omitted))
                .minute(.twoDigits)
                .second(.twoDigits)
        )
    }
}

private struct StationMapDotAnnotation: View {
    var body: some View {
        Circle()
            .fill(Color(.darkGray))
            .frame(width: 6, height: 6)
            .overlay {
                Circle()
                    .stroke(Color.white.opacity(0.9), lineWidth: 2)
            }
            .shadow(color: Color.black.opacity(0.18), radius: 3, y: 1)
    }
}

private struct TrainMapDotAnnotation: View {
    let trainType: String?
    let isHighlighted: Bool

    var body: some View {
        Circle()
            .fill(isHighlighted ? Color.orange : trainMarkerColor(for: trainType))
            .frame(width: isHighlighted ? 9 : 7, height: isHighlighted ? 9 : 7)
            .overlay {
                Circle()
                    .stroke(Color.white.opacity(0.95), lineWidth: 2)
            }
            .shadow(color: Color.black.opacity(isHighlighted ? 0.24 : 0.18), radius: isHighlighted ? 4 : 3, y: 1)
    }
}

private struct CurrentLocationAnnotation: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.accentColor.opacity(0.20))
                .frame(width: 28, height: 28)

            Circle()
                .fill(Color.accentColor)
                .frame(width: 14, height: 14)
                .overlay {
                    Circle()
                        .stroke(Color.white, lineWidth: 3)
                }
        }
        .shadow(color: Color.accentColor.opacity(0.22), radius: 8, y: 2)
    }
}

private struct RouteStartAnnotation: View {
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(Color.green)
                    .frame(width: 18, height: 18)
                    .overlay {
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                    }

                Image(systemName: "flag.fill")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(.white)
            }

            Text("Start")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.thinMaterial, in: Capsule())
        }
        .shadow(color: Color.black.opacity(0.14), radius: 6, y: 2)
    }
}

private struct StationMapAnnotation: View {
    let isHighlighted: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(.darkGray))
                .frame(width: isHighlighted ? 20 : 16, height: isHighlighted ? 20 : 16)
                .overlay {
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                }

            Image(systemName: "building.columns.fill")
                .font(isHighlighted ? .caption.bold() : .caption2.bold())
                .foregroundStyle(.white)
                .padding(isHighlighted ? 4 : 3)
        }
        .overlay(alignment: .bottom) {
            Triangle()
                .fill(Color.white)
                .frame(width: isHighlighted ? 8 : 6, height: isHighlighted ? 5 : 4)
                .offset(y: isHighlighted ? 3 : 2)
        }
        .shadow(color: Color.black.opacity(isHighlighted ? 0.24 : 0.18), radius: isHighlighted ? 6 : 4, y: 2)
    }
}

private struct TrainMapAnnotation: View {
    let trainType: String?
    let isHighlighted: Bool

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(markerColor)
                    .frame(width: isHighlighted ? 28 : 24, height: isHighlighted ? 28 : 24)
                    .overlay {
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                    }

                Image(systemName: "tram.fill")
                    .font(isHighlighted ? .caption.bold() : .caption2.bold())
                    .foregroundStyle(.white)
                    .padding(isHighlighted ? 5 : 4)
            }
            .overlay(alignment: .bottom) {
                Triangle()
                    .fill(Color.white)
                    .frame(width: isHighlighted ? 10 : 8, height: isHighlighted ? 6 : 5)
                    .offset(y: isHighlighted ? 5 : 4)
            }
            .shadow(color: markerColor.opacity(0.30), radius: isHighlighted ? 7 : 4, y: 2)
        }
    }

    private var markerColor: Color {
        isHighlighted ? .orange : trainMarkerColor(for: trainType)
    }
}

private func trainMarkerColor(for trainType: String?) -> Color {
    let normalizedTrainType = trainType?
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .uppercased()

    switch normalizedTrainType {
    case "SPFG", "GT":
        return .green
    default:
        return .accentColor
    }
}

private struct SelectedTrainCard: View {
    let train: TrainMessage
    let routeText: String
    let distanceText: String?
    let totalDistanceText: String?
    let passedDistanceText: String?
    let departureTimeText: String?
    let arrivalTimeText: String?
    let travelTimeText: String?
    let remainingTimeText: String?
    let nextStationText: String?
    let nextStationDetailText: String?
    let progress: Double?
    let onOpenRoute: () -> Void
    let onCollapse: () -> Void
    let onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        TrainCountryFlagBadge(countryCode: train.countryCode)

                        let lineNumber = displayLineNumber(for: train)

                        Text(lineNumber ?? displayTrainNumber(for: train))
                            .font(.headline.monospacedDigit().weight(.bold))
                            .foregroundStyle(.primary)

                        if lineNumber != nil {
                            Text("•")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)

                            Text(displayTrainNumber(for: train))
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }

                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 8)

                HStack(spacing: 8) {
                    Button(action: onCollapse) {
                        Image(systemName: "chevron.up")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                            .background(Color.black.opacity(0.05), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Minimer valgt tog")

                    Button(action: onClear) {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                            .background(Color.black.opacity(0.05), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Fjern valgt tog")
                }
            }

            VStack(spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(routeText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(alignment: .top, spacing: 20) {
                    TrainInfoColumn(title: "Avgang", value: departureTimeText ?? "Ukjent", valueWeight: .bold)
                    Spacer(minLength: 0)
                    TrainInfoColumn(title: "Ankomst", value: arrivalTimeText ?? "Ukjent", alignment: .trailing, valueWeight: .bold)
                }

                HStack(alignment: .top, spacing: 20) {
                    TrainInfoColumn(title: "Reisetid", value: travelTimeText ?? "Ukjent", valueWeight: .bold)
                    Spacer(minLength: 0)
                    TrainInfoColumn(title: "Gjenstår", value: remainingTimeText ?? "Ukjent", alignment: .trailing, valueWeight: .bold)
                }

                if nextStationText != nil {
                    Divider()
                        .overlay(Color.primary.opacity(0.08))

                    HStack(alignment: .top, spacing: 20) {
                        TrainInfoColumn(title: "Neste stasjon", value: nextStationText ?? "Ukjent", valueWeight: .bold)
                        Spacer(minLength: 0)
                        TrainInfoColumn(title: "Ankomst", value: nextStationDetailText ?? "Ukjent", alignment: .trailing, valueWeight: .bold)
                    }
                }
            }

            Divider()
                .overlay(Color.primary.opacity(0.08))

            HStack(alignment: .top, spacing: 20) {
                TrainInfoColumn(title: "Operatør", value: displayCompany(for: train) ?? "Operatør mangler")
                Spacer(minLength: 0)
                TrainInfoColumn(title: "Togtype", value: normalizedText(train.trainType) ?? "Ukjent", alignment: .trailing)
            }

            HStack(alignment: .top, spacing: 20) {
                TrainInfoColumn(title: "ServiceTime", value: displayServiceTime(for: train))
                Spacer(minLength: 0)
                TrainInfoColumn(title: "Koordinater", value: displayCoordinateText(for: train), alignment: .trailing)
            }

            if let totalDistanceText, let progress {
                RouteProgressView(
                    progress: progress,
                    remainingDistanceText: distanceText,
                    totalDistanceText: totalDistanceText,
                    passedDistanceText: passedDistanceText,
                    onOpenRoute: onOpenRoute
                )
            }

        }
        .padding(16)
        .frame(maxWidth: 430, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.45), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.14), radius: 18, y: 8)
    }
}

private struct CollapsedSelectedTrainCard: View {
    let train: TrainMessage
    let routeText: String
    let onExpand: () -> Void
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onExpand) {
                HStack(spacing: 10) {
                    TrainCountryFlagBadge(countryCode: train.countryCode)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(displayLineNumber(for: train) ?? displayTrainNumber(for: train))
                            .font(.subheadline.monospacedDigit().weight(.bold))
                            .foregroundStyle(.primary)

                        Text(routeText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Utvid valgt tog")

            HStack(spacing: 8) {
                Button(action: onExpand) {
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Color.black.opacity(0.05), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Utvid valgt tog")

                Button(action: onClear) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Color.black.opacity(0.05), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Fjern valgt tog")
            }
        }
        .padding(14)
        .frame(maxWidth: 430, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.45), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.12), radius: 14, y: 6)
    }
}

private struct RouteProgressView: View {
    let progress: Double
    let remainingDistanceText: String?
    let totalDistanceText: String
    let passedDistanceText: String?
    let onOpenRoute: () -> Void

    var body: some View {
        VStack(spacing: 7) {
            GeometryReader { geometry in
                let clampedProgress = min(max(progress, 0), 1)
                let markerCenterX = max(10, min(geometry.size.width - 10, geometry.size.width * clampedProgress))
                let lineCenterY = geometry.size.height / 2

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.12))
                        .frame(height: 4)

                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: max(4, geometry.size.width * clampedProgress), height: 4)

                    Button(action: onOpenRoute) {
                        Image(systemName: "tram.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 20, height: 20)
                            .background(.thinMaterial, in: Circle())
                            .overlay {
                                Circle()
                                    .stroke(Color.white.opacity(0.55), lineWidth: 1)
                            }
                            .shadow(color: Color.black.opacity(0.12), radius: 4, y: 2)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Apne togrute")
                    .position(x: markerCenterX, y: lineCenterY)
                }
            }
            .frame(height: 12)

            ZStack {
                HStack {
                    Text("0 km")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)

                    Spacer(minLength: 12)

                    Text(totalDistanceText)
                        .font(.caption2.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                progressMarkerSummary
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    private var progressMarkerSummary: some View {
        HStack(spacing: 6) {
            if let passedDistanceText {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.left")
                        .font(.caption2)
                    Text(passedDistanceText)
                        .font(.caption2.monospacedDigit().weight(.bold))
                }
            }

            if passedDistanceText != nil, remainingDistanceText != nil {
                Text("•")
                    .font(.caption2)
            }

            if let remainingDistanceText {
                HStack(spacing: 3) {
                    Text(remainingDistanceText)
                        .font(.caption2.monospacedDigit().weight(.bold))
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                }
            }
        }
        .foregroundStyle(.secondary)
    }
}

private struct SelectedStationCard: View {
    let station: TraseStation
    let distanceText: String?
    let onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        StationCountryFlagBadge(countryCode: station.countryCode)

                        Text(station.name)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                    }

                    Text(station.displayShortNameLine)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                }

                Spacer(minLength: 8)

                Button(action: onClear) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Color.black.opacity(0.05), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Fjern valgt stasjon")
            }

            HStack(alignment: .top, spacing: 20) {
                if station.isBorderStation {
                    TrainInfoColumn(title: "Type", value: "Grensestasjon")
                }

                TrainInfoColumn(title: "Koordinater", value: station.displayCoordinateText)
                Spacer(minLength: 0)

                if let distanceText {
                    TrainInfoColumn(title: "Avstand", value: distanceText, alignment: .trailing)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: 430, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.45), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.14), radius: 18, y: 8)
    }
}

private struct TrainCountryFlagBadge: View {
    let countryCode: String

    var body: some View {
        Group {
            switch countryCode.uppercased() {
            case "NO":
                SmallNorwayFlagBadge()
            case "SE":
                SmallSwedenFlagBadge()
            default:
                Image(systemName: "tram.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 34, height: 22)
                    .background(AppTheme.elevatedSurface, in: Rectangle())
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}

private struct TrainListCountryFlagBadge: View {
    let countryCode: String

    var body: some View {
        Group {
            switch countryCode.uppercased() {
            case "NO":
                TrainListNorwayFlagBadge()
            case "SE":
                TrainListSwedenFlagBadge()
            default:
                Image(systemName: "tram.fill")
                    .font(.headline)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 42, height: 28)
                    .background(AppTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

private struct TrainListNorwayFlagBadge: View {
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

private struct TrainListSwedenFlagBadge: View {
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

private struct StationCountryFlagBadge: View {
    let countryCode: String

    var body: some View {
        Group {
            switch countryCode.uppercased() {
            case "NO":
                SmallNorwayFlagBadge()
            case "SE":
                SmallSwedenFlagBadge()
            default:
                Image(systemName: "building.columns.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(.darkGray))
                    .frame(width: 28, height: 28)
                    .background(AppTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 9))
            }
        }
    }
}

private struct SmallNorwayFlagBadge: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color(red: 0.73, green: 0.11, blue: 0.17))

            Rectangle()
                .fill(.white)
                .frame(width: 5)
                .offset(x: -5)

            Rectangle()
                .fill(.white)
                .frame(height: 5)

            Rectangle()
                .fill(Color(red: 0.0, green: 0.13, blue: 0.36))
                .frame(width: 3)
                .offset(x: -5)

            Rectangle()
                .fill(Color(red: 0.0, green: 0.13, blue: 0.36))
                .frame(height: 3)
        }
        .frame(width: 34, height: 22)
    }
}

private struct SmallSwedenFlagBadge: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color(red: 0.0, green: 0.32, blue: 0.61))

            Rectangle()
                .fill(Color(red: 0.98, green: 0.80, blue: 0.17))
                .frame(width: 5)
                .offset(x: -5)

            Rectangle()
                .fill(Color(red: 0.98, green: 0.80, blue: 0.17))
                .frame(height: 5)
        }
        .frame(width: 34, height: 22)
    }
}

private struct TrainInfoColumn: View {
    let title: String
    let value: String
    var alignment: HorizontalAlignment = .leading
    var valueWeight: Font.Weight = .regular

    var body: some View {
        VStack(alignment: alignment, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            Text(value)
                .font(.footnote.monospacedDigit().weight(valueWeight))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
    }
}

@MainActor
@Observable
private final class TrainMapLocationManager: NSObject, CLLocationManagerDelegate {
    var currentLocation: MapCoordinate?
    var authorizationStatus: CLAuthorizationStatus

    var hasLocationAccess: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    private let manager: CLLocationManager

    override init() {
        let manager = CLLocationManager()
        self.manager = manager
        self.authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestCurrentLocation() {
        switch authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            break
        @unknown default:
            break
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus

        if hasLocationAccess {
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else {
            return
        }

        currentLocation = MapCoordinate(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    }
}

private struct MapCoordinate: Equatable {
    let latitude: Double
    let longitude: Double

    var clCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

private struct ConnectionStatusDot: View {
    let state: ConnectionState

    @State private var isPulsing = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 14, height: 14)
            .overlay {
                Circle()
                    .stroke(Color.white.opacity(0.9), lineWidth: 2)
            }
            .scaleEffect(state == .connected && isPulsing ? 1.18 : 1.0)
            .shadow(color: color.opacity(state == .connected ? 0.45 : 0.20), radius: state == .connected ? 8 : 4, y: 1)
            .onAppear {
                updatePulse()
            }
            .onChange(of: state) { _, _ in
                updatePulse()
            }
    }

    private var color: Color {
        Color.accentColor
    }

    private func updatePulse() {
        guard state == .connected else {
            withAnimation(.easeOut(duration: 0.2)) {
                isPulsing = false
            }
            return
        }

        isPulsing = false
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            isPulsing = true
        }
    }
}

private struct SystemChromeMaterialView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: .systemChromeMaterial)
    }
}

private enum TrainMapMode: String, CaseIterable, Identifiable {
    case standard
    case traffic
    case satellite
    case hybrid

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard:
            return "Standard"
        case .traffic:
            return "Trafikk"
        case .satellite:
            return "Satellitt"
        case .hybrid:
            return "Hybrid"
        }
    }

    var systemImage: String {
        switch self {
        case .standard:
            return "map"
        case .traffic:
            return "car.fill"
        case .satellite:
            return "globe.americas.fill"
        case .hybrid:
            return "square.2.layers.3d"
        }
    }

    var mapStyle: MapStyle {
        switch self {
        case .standard:
            return .standard(elevation: .realistic)
        case .traffic:
            return .standard(elevation: .realistic, showsTraffic: true)
        case .satellite:
            return .imagery(elevation: .realistic)
        case .hybrid:
            return .hybrid(elevation: .realistic, showsTraffic: true)
        }
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

private func displayLineNumber(for trainMessage: TrainMessage) -> String? {
    normalizedText(trainMessage.lineNumber)
}

private func displayTrainNumber(for trainMessage: TrainMessage) -> String {
    normalizedText(trainMessage.trainNo)
        ?? normalizedText(trainMessage.advertisementTrainNo)
        ?? normalizedText(trainMessage.trainPosition?.geoJson.properties.trainNumber)
        ?? "Tog"
}

private func displayCompany(for trainMessage: TrainMessage) -> String? {
    normalizedText(trainMessage.company)
        ?? normalizedText(trainMessage.trainPosition?.toc)
        ?? normalizedText(trainMessage.trainPosition?.geoJson.properties.operatorRef)
}

private func displayOriginTime(for trainMessage: TrainMessage) -> String {
    guard let date = trainMessage.originTime else {
        return "Ukjent"
    }

    return date.formatted(
        .dateTime
            .hour(.twoDigits(amPM: .omitted))
            .minute(.twoDigits)
            .second(.twoDigits)
    )
}

private func displayServiceTime(for trainMessage: TrainMessage) -> String {
    guard let date = trainMessage.trainPosition?.geoJson.properties.serviceTime else {
        return "Ukjent"
    }

    return date.formatted(
        .dateTime
            .hour(.twoDigits(amPM: .omitted))
            .minute(.twoDigits)
            .second(.twoDigits)
    )
}

private func displayCoordinateText(for trainMessage: TrainMessage) -> String {
    guard
        let coordinates = trainMessage.trainPosition?.geoJson.geometry.coordinates,
        coordinates.count >= 2
    else {
        return "Ukjent"
    }

    return String(format: "%.5f, %.5f", coordinates[1], coordinates[0])
}

private func normalizedText(_ value: String?) -> String? {
    let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return normalized.isEmpty ? nil : normalized
}
private extension MKCoordinateRegion {
    func contains(coordinate: CLLocationCoordinate2D) -> Bool {
        let minLatitude = center.latitude - (span.latitudeDelta / 2)
        let maxLatitude = center.latitude + (span.latitudeDelta / 2)
        let minLongitude = center.longitude - (span.longitudeDelta / 2)
        let maxLongitude = center.longitude + (span.longitudeDelta / 2)

        return coordinate.latitude >= minLatitude
            && coordinate.latitude <= maxLatitude
            && coordinate.longitude >= minLongitude
            && coordinate.longitude <= maxLongitude
    }
}
