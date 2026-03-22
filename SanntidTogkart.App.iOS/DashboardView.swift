import SwiftUI

struct DashboardView: View {
    @State private var connectionCenter = SignalRConnectionCenter.shared
    let user: EntraIDUser
    let authSession: AuthSession
    let onLogout: () -> Void

    var body: some View {
        TabView {
            HomeTabView()
            .tabItem {
                Label("Hjem", systemImage: "house")
            }

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
                                    .stroke(Color(.systemBackground), lineWidth: 1.5)
                            }
                            .offset(x: 6, y: -2)
                    }

                    Text("Kart")
                }
            }

            RoutesTabView()
            .tabItem {
                Label("Ruter", systemImage: "arrow.triangle.swap")
            }

            StationsTabView()
            .tabItem {
                Label("Stasjoner", systemImage: "building.columns.fill")
            }

            UserTabView(user: user, authSession: authSession, onLogout: onLogout)
            .tabItem {
                Label("Meg", systemImage: "person.fill")
            }
        }
    }
}
