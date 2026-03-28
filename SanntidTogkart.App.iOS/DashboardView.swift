import SwiftUI

struct DashboardView: View {
    @State private var connectionCenter = SignalRConnectionCenter.shared
    let user: EntraIDUser
    let authSession: AuthSession
    let onLogout: () -> Void

    var body: some View {
        TabView {
            TrainMapTabView()
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
            .tabItem {
                Label("Favoritter", systemImage: "star.fill")
            }

            RoutesTabView()
            .tabItem {
                Label("Ruter", systemImage: "arrow.triangle.swap")
            }

            StationsTabView()
            .tabItem {
                Label("Stasjoner", systemImage: "building.columns.fill")
            }

            SettingsTabView(user: user, authSession: authSession, onLogout: onLogout)
            .tabItem {
                Label("Innstillinger", systemImage: "gearshape.fill")
            }
        }
    }
}
