import SwiftUI

struct SettingsTabView: View {
    let user: EntraIDUser
    @Bindable var authSession: AuthSession
    let onLogout: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    navigationMenuCard
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

            rowDivider

            NavigationLink {
                ConfigView(authSession: authSession)
            } label: {
                menuRow(title: "Innstillinger", systemImage: "slider.horizontal.3")
            }
            .buttonStyle(.plain)

            rowDivider

            NavigationLink {
                FreightTrainOperatorsView()
            } label: {
                menuRow(title: "Godstogoperatører", systemImage: "list.bullet")
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
