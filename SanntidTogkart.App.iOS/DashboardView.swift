import SwiftUI

struct DashboardView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var navigationCenter = AppNavigationCenter.shared
    let user: EntraIDUser
    let authSession: AuthSession
    let onLogout: () -> Void

    var body: some View {
        TabView(selection: selectedTabBinding) {
            TrainsTabView()
            .tag(DashboardTab.trains)
            .tabItem {
                tabItemLabel("NÅ", systemImage: "clock")
            }

            TrainMapTabView()
            .toolbarColorScheme(colorScheme == .dark ? .dark : .light, for: .tabBar)
            .tag(DashboardTab.map)
            .tabItem {
                VStack(spacing: 2) {
                    Image(systemName: "map")
                    Text("Kart")
                }
                .foregroundColor(colorScheme == .dark ? .white : .black)
                .environment(\.symbolVariants, .none)
            }

            SettingsTabView(user: user, authSession: authSession, onLogout: onLogout)
            .tag(DashboardTab.settings)
            .tabItem {
                tabItemLabel("Mer", systemImage: "ellipsis.circle")
            }
        }
    }

    private var selectedTabBinding: Binding<DashboardTab> {
        Binding(
            get: { navigationCenter.selectedDashboardTab },
            set: { navigationCenter.selectedDashboardTab = $0 }
        )
    }

    @ViewBuilder
    private func tabItemLabel(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .environment(\.symbolVariants, .none)
            .symbolRenderingMode(.monochrome)
    }
}
