import SwiftUI
import UIKit
import CoreLocation

struct SettingsTabView: View {
    let user: EntraIDUser
    @Bindable var authSession: AuthSession
    let onLogout: () -> Void
    @AppStorage("appAppearanceMode") private var appAppearanceModeRawValue = AppAppearanceMode.system.rawValue
    @AppStorage("showAppIntroductionOnNextLaunch") private var showAppIntroductionOnNextLaunch = false
    @State private var selectedEnvironment = AuthConfig.currentEnvironment
    @State private var isSwitchingEnvironment = false
    @State private var locationAccessManager = SettingsLocationAccessManager()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    profileCard
                    accountCard
                    appearanceCard
                    environmentCard
                    securityCard
                    locationCard
                    onboardingCard
                    appInfoCard
                    actionCard
                }
                .padding(20)
                .appReadableContentWidth()
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Innstillinger")
        }
    }

    @ViewBuilder
    private var profileImage: some View {
        if let profileImageData = user.profileImageData, let uiImage = UIImage(data: profileImageData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 96, height: 96)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.accentColor.opacity(0.2), lineWidth: 2)
                )
        } else {
            Image(systemName: "person.crop.circle")
                .resizable()
                .frame(width: 96, height: 96)
                .foregroundStyle(Color.accentColor)
        }
    }

    private var profileCard: some View {
        VStack(spacing: 14) {
            profileImage
                .frame(width: 104, height: 104)

            VStack(spacing: 6) {
                Text(user.displayName)
                    .font(.title2.weight(.bold))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(
            AppTheme.surface,
            in: RoundedRectangle(cornerRadius: 8)
        )
    }

    private var accountCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Konto", systemImage: "person.text.rectangle")
                .font(.headline)

            infoRow(title: "Navn", value: user.displayName)
            infoRow(title: "Bruker", value: user.username)
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

    private var environmentCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Miljø", systemImage: "network")
                .font(.headline)

            Text("Bytt SignalR- og Entra-konfigurasjon uten å starte appen på nytt.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Picker("Miljø", selection: $selectedEnvironment) {
                ForEach(AppEnvironment.allCases) { environment in
                    Text(environment.title).tag(environment)
                }
            }
            .pickerStyle(.segmented)
            .disabled(isSwitchingEnvironment)
            .onChange(of: selectedEnvironment) { _, newValue in
                Task {
                    isSwitchingEnvironment = true
                    await SignalRService.switchEnvironment(to: newValue)
                    isSwitchingEnvironment = false
                }
            }
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

    private var onboardingCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Introduksjon", systemImage: "sparkles.rectangle.stack")
                .font(.headline)

            Text("Slå på dette hvis du vil se appintroduksjonen neste gang appen startes.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Toggle(isOn: $showAppIntroductionOnNextLaunch) {
                Label("Vis ved neste appstart", systemImage: showAppIntroductionOnNextLaunch ? "play.rectangle.on.rectangle.fill" : "play.rectangle.on.rectangle")
                    .font(.subheadline.weight(.medium))
            }
            .tint(.accentColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 8))
    }

    private var securityCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Sikkerhet", systemImage: "faceid")
                .font(.headline)

            Text("Aktiver Face ID for å holde deg innlogget mellom appstarter.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Toggle(isOn: Binding(
                get: { authSession.isBiometricEnabled },
                set: { isEnabled in
                    Task {
                        let didUpdate = await authSession.setBiometricEnabled(isEnabled)
                        if !didUpdate {
                            return
                        }
                    }
                }
            )) {
                Label("Bruk Face ID", systemImage: authSession.isBiometricEnabled ? "checkmark.shield" : "faceid")
                    .font(.subheadline.weight(.medium))
            }
            .tint(.accentColor)
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

    private var appearanceCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Utseende", systemImage: "circle.lefthalf.filled")
                .font(.headline)

            Text("Velg om appen skal folge systemet eller alltid bruke lys eller mørk modus.")
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

    private var actionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Økt", systemImage: "bolt.horizontal.circle")
                .font(.headline)

            Text("Du er innlogget med Bane NOR SSO.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button(role: .destructive, action: onLogout) {
                Label("Logg ut", systemImage: "rectangle.portrait.and.arrow.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
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

    var statusIconName: String {
        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            "location.fill"
        case .denied, .restricted:
            "location.slash"
        case .notDetermined:
            "location"
        @unknown default:
            "questionmark.circle"
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

        guard hasLocationAccess else {
            return
        }

        openAppSettings()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            return
        }

        UIApplication.shared.open(url)
    }
}

