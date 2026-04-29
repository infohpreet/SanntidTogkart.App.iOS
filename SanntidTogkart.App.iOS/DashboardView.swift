import SwiftUI

struct DashboardView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var navigationCenter = AppNavigationCenter.shared
    let user: EntraIDUser
    let authSession: AuthSession
    let onLogout: () -> Void

    var body: some View {
        TabView(selection: selectedTabBinding) {
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

            FavoriteTabView()
            .tag(DashboardTab.favorites)
            .tabItem {
                tabItemLabel("Favoritter", systemImage: "star")
            }

            RoutesTabView()
            .tag(DashboardTab.routes)
            .tabItem {
                tabItemLabel("Ruter", systemImage: "arrow.triangle.swap")
            }

            StationsTabView()
            .tag(DashboardTab.stations)
            .tabItem {
                tabItemLabel("Stasjoner", systemImage: "tram.fill.tunnel")
            }

            SettingsTabView(user: user, authSession: authSession, onLogout: onLogout)
            .tag(DashboardTab.settings)
            .tabItem {
                tabItemLabel("Innstillinger", systemImage: "gearshape")
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
