import CoreLocation
import Observation
import SwiftUI
import UIKit

struct SettingsTabView: View {
    let user: EntraIDUser
    @Bindable var authSession: AuthSession
    let onLogout: () -> Void

    @AppStorage("appAppearanceMode") private var appAppearanceModeRawValue = AppAppearanceMode.system.rawValue
    @AppStorage(AppNavigationCenter.startupDashboardTabKey) private var startupDashboardTabRawValue = DashboardTab.home.rawValue
    @State private var selectedEnvironment = AuthConfig.currentEnvironment
    @State private var locationAccessManager = SettingsLocationAccessManager()
    @State private var logStore = AppLogStore.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    navigationMenuCard
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
            .navigationTitle("Mer")
        }
    }

    private var navigationMenuCard: some View {
        VStack(spacing: 0) {
            NavigationLink {
                ProfileView(user: user, authSession: authSession, onLogout: onLogout)
            } label: {
                menuRow(title: "Profil", systemImage: "person.crop.circle")
            }
            .buttonStyle(.plain)

            rowDivider

            NavigationLink {
                RoutesTabView()
            } label: {
                menuRow(title: "Tog", systemImage: "arrow.triangle.swap")
            }
            .buttonStyle(.plain)

            rowDivider

            NavigationLink {
                SettingsIntroductionPreviewView()
            } label: {
                menuRow(title: "Introduksjon", systemImage: "sparkles.rectangle.stack")
            }
            .buttonStyle(.plain)
        }
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.border, lineWidth: 1)
        }
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(AppTheme.border)
            .frame(height: 1)
            .padding(.leading, 58)
    }

    private func menuRow(title: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 28, height: 28)
                .background(Color.accentColor.opacity(0.12), in: Circle())

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
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

            Text("Velg mellom Training og Staging. Prod er midlertidig deaktivert.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Picker("Miljø", selection: $selectedEnvironment) {
                ForEach(AppEnvironment.allCases) { environment in
                    Text(environment.title).tag(environment)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedEnvironment) { oldValue, newValue in
                guard newValue != .prod else {
                    selectedEnvironment = oldValue
                    return
                }

                Task {
                    await SignalRService.switchEnvironment(to: newValue)
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
}

private struct SettingsIntroductionPreviewView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        AppIntroductionView {
            dismiss()
        }
        .navigationBarBackButtonHidden(true)
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
