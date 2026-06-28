import CoreLocation
import Observation
import SwiftUI
import UIKit

struct ConfigView: View {
    @Bindable var authSession: AuthSession
    @AppStorage("appAppearanceMode") private var appAppearanceModeRawValue = AppAppearanceMode.system.rawValue
    @AppStorage(AppNavigationCenter.startupDashboardTabKey) private var startupDashboardTabRawValue = DashboardTab.home.rawValue
    @State private var selectedEnvironment = AuthConfig.currentEnvironment
    @State private var pendingEnvironment: AppEnvironment?
    @State private var isShowingEnvironmentChangeConfirmation = false
    @State private var isSwitchingEnvironment = false
    @State private var locationAccessManager = SettingsLocationAccessManager()
    @State private var logStore = AppLogStore.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                startupTabCard
                appearanceCard
                environmentCard
                locationCard
                logsCard
                appInfoCard
            }
            .padding(20)
            .appReadableContentWidth()
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Innstillinger")
        .alert("Bytte miljø?", isPresented: $isShowingEnvironmentChangeConfirmation) {
            Button("Avbryt", role: .cancel) {
                pendingEnvironment = nil
                selectedEnvironment = AuthConfig.currentEnvironment
            }
            Button("Fortsett") {
                guard let pendingEnvironment else {
                    return
                }

                Task {
                    isSwitchingEnvironment = true
                    await SignalRService.switchEnvironment(to: pendingEnvironment)
                    authSession.resetForEnvironmentChange(
                        message: "Miljøet ble byttet. Logg inn på nytt for å hente tilgang til det nye miljøet."
                    )
                    self.pendingEnvironment = nil
                    selectedEnvironment = AuthConfig.currentEnvironment
                    isSwitchingEnvironment = false
                }
            }
        } message: {
            Text("Bytte av miljø kan kreve ny innlogging før sanntidsdata fungerer igjen. Vil du fortsette?")
        }
    }

    private var appearanceCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Utseende", systemImage: "circle.lefthalf.filled")
                .font(.headline)

            Text("Velg om appen skal følge systemet eller alltid bruke lys eller mørk modus.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Picker("Utseende", selection: $appAppearanceModeRawValue) {
                ForEach(AppAppearanceMode.allCases) { mode in
                    Text(mode.title).tag(mode.rawValue)
                }
            }
            .pickerStyle(.segmented)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 8))
    }

    private var startupTabCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Startfane", systemImage: "rectangle.stack")
                .font(.headline)

            Text("Velg hvilken fane som skal vises når appen starter.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Picker("Startfane", selection: $startupDashboardTabRawValue) {
                ForEach(DashboardTab.startupTabs) { tab in
                    Text(tab.title).tag(tab.rawValue)
                }
            }
            .pickerStyle(.segmented)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 8))
    }

    private var environmentCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Miljø", systemImage: "network")
                .font(.headline)

            Text("Bytt SignalR- og Entra-konfigurasjon. Ny innlogging kan være nødvendig etter miljøbytte.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Picker("Miljø", selection: environmentSelectionBinding) {
                ForEach(AppEnvironment.allCases) { environment in
                    Text(environment.title).tag(environment)
                }
            }
            .pickerStyle(.segmented)
            .disabled(isSwitchingEnvironment)

            if isSwitchingEnvironment {
                HStack {
                    Spacer()
                    ProgressView()
                        .controlSize(.small)
                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 8))
    }

    private var locationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Posisjon", systemImage: "location")
                .font(.headline)

            Text("Aktiver nåværende posisjon for å kunne navigere kartet til din posisjon og bruke posisjon i relevante visninger.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(alignment: .center, spacing: 12) {
                Text(locationAccessManager.statusText)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(locationAccessManager.statusColor)

                Spacer()

                Toggle(
                    "Bruk nåværende posisjon",
                    isOn: Binding(
                        get: { locationAccessManager.hasLocationAccess },
                        set: { isEnabled in
                            locationAccessManager.setLocationAccessEnabled(isEnabled)
                        }
                    )
                )
                .labelsHidden()
                .tint(.accentColor)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 8))
    }

    private var logsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Logger", systemImage: "doc.text.magnifyingglass")
                .font(.headline)

            Text("Vis lagrede feil, dekodingsfeil og andre registrerte appfeil.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            NavigationLink {
                AppLogView()
            } label: {
                HStack(spacing: 12) {
                    Label("Åpne logger", systemImage: "list.bullet.rectangle")
                        .font(.subheadline.weight(.medium))

                    Spacer()

                    Text("\(logStore.entryCount)")
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.secondary)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 8))
    }

    private var appInfoCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("App", systemImage: "info.circle")
                .font(.headline)

            infoRow(title: "Versjon", value: "\(appVersion) (\(appBuild))")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 8))
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Ukjent"
    }

    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Ukjent"
    }

    private var environmentSelectionBinding: Binding<AppEnvironment> {
        Binding(
            get: { selectedEnvironment },
            set: { newValue in
                guard !isSwitchingEnvironment else {
                    return
                }

                guard newValue != selectedEnvironment else {
                    return
                }

                pendingEnvironment = newValue
                isShowingEnvironmentChangeConfirmation = true
            }
        )
    }
}

@MainActor
@Observable
private final class SettingsLocationAccessManager: NSObject, CLLocationManagerDelegate {
    var authorizationStatus: CLAuthorizationStatus

    var hasLocationAccess: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    var statusText: String {
        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            "Nåværende posisjon er aktivert"
        case .denied, .restricted:
            "Tilgang er avslått"
        case .notDetermined:
            "Ikke aktivert"
        @unknown default:
            "Ukjent status"
        }
    }

    var statusColor: Color {
        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            .green
        case .denied, .restricted:
            .orange
        case .notDetermined:
            .secondary
        @unknown default:
            .secondary
        }
    }

    private let manager: CLLocationManager

    override init() {
        let manager = CLLocationManager()
        self.manager = manager
        self.authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
    }

    func setLocationAccessEnabled(_ isEnabled: Bool) {
        if isEnabled {
            switch authorizationStatus {
            case .notDetermined:
                manager.requestWhenInUseAuthorization()
            case .denied, .restricted:
                openAppSettings()
            case .authorizedAlways, .authorizedWhenInUse:
                return
            @unknown default:
                openAppSettings()
            }
            return
        }

        openAppSettings()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
    }

    private func openAppSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
            return
        }

        UIApplication.shared.open(settingsURL)
    }
}
