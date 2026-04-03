import SwiftUI

struct DashboardView: View {
    @State private var connectionCenter = SignalRConnectionCenter.shared
    @State private var navigationCenter = AppNavigationCenter.shared
    let user: EntraIDUser
    let authSession: AuthSession
    let onLogout: () -> Void

    var body: some View {
        TabView(selection: selectedTabBinding) {
            TrainMapTabView()
            .tag(DashboardTab.map)
            .tabItem {
                VStack(spacing: 2) {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "map")

                        Circle()
                            .fill(connectionCenter.state.color)
                            .frame(width: 7, height: 7)
                            .overlay {
                                Circle()
                                    .stroke(AppTheme.background, lineWidth: 1.5)
                            }
                            .offset(x: 6, y: -2)
                    }

                    Text("Kart")
                }
            }

            FavoriteTabView()
            .tag(DashboardTab.favorites)
            .tabItem {
                Label("Favoritter", systemImage: "star.fill")
            }

            RoutesTabView()
            .tag(DashboardTab.routes)
            .tabItem {
                Label("Ruter", systemImage: "arrow.triangle.swap")
            }

            StationsTabView()
            .tag(DashboardTab.stations)
            .tabItem {
                Label("Stasjoner", systemImage: "building.columns.fill")
            }

            SettingsTabView(user: user, authSession: authSession, onLogout: onLogout)
            .tag(DashboardTab.settings)
            .tabItem {
                Label("Innstillinger", systemImage: "gearshape.fill")
            }
        }
    }

    private var selectedTabBinding: Binding<DashboardTab> {
        Binding(
            get: { navigationCenter.selectedDashboardTab },
            set: { navigationCenter.selectedDashboardTab = $0 }
        )
    }
}
