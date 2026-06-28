import SwiftUI
import UIKit

struct ProfileView: View {
    let user: EntraIDUser
    @Bindable var authSession: AuthSession
    let onLogout: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                profileHeroCard
                accountCard
                securityCard
                sessionCard
            }
            .padding(20)
            .appReadableContentWidth()
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Profil")
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

    private var profileHeroCard: some View {
        VStack(spacing: 14) {
            profileImage
                .frame(width: 104, height: 104)

            Text(user.displayName)
                .font(.title2.weight(.bold))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 8))
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
                        _ = await authSession.setBiometricEnabled(isEnabled)
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

    private var sessionCard: some View {
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
