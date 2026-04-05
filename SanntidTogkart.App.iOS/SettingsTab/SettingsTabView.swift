import SwiftUI
import UIKit

struct SettingsTabView: View {
    let user: EntraIDUser
    @Bindable var authSession: AuthSession
    let onLogout: () -> Void
    @AppStorage("appAppearanceMode") private var appAppearanceModeRawValue = AppAppearanceMode.system.rawValue
    @State private var selectedEnvironment = AuthConfig.currentEnvironment
    @State private var isSwitchingEnvironment = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    profileCard
                    accountCard
                    appearanceCard
                    environmentCard
                    securityCard
                    actionCard
                }
                .padding(20)
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
}
