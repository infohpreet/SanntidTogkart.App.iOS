import SwiftUI

struct FavoriteTabView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    welcomeSection
                    statisticsTile
                }
                .padding(20)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Favoritter")
        }
    }

    private var welcomeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sanntid Togkart")
                .font(.system(size: 30, weight: .bold, design: .rounded))

            Text("Få rask tilgang til live togdata og åpne statistikkoversikten når du trenger detaljene.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statisticsTile: some View {
        NavigationLink {
            StatisticsView()
        } label: {
            HStack(spacing: 18) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: 64, height: 64)

                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Statistikk")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)

                    Text("Åpne oversikten for stasjoner, ruter, operatører og aktive tog.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                Image(systemName: "arrow.right")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [
                        Color.accentColor.opacity(0.16),
                        Color.accentColor.opacity(0.05),
                        AppTheme.surface
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 24, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.accentColor.opacity(0.18), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.05), radius: 18, y: 10)
        }
        .buttonStyle(.plain)
    }
}

struct StatisticsView: View {
    var body: some View {
        HomeStatisticsContentView()
    }
}

struct HomeConnectionStatusDot: View {
    let state: ConnectionState

    @State private var isPulsing = false

    var body: some View {
        Circle()
            .fill(state.color)
            .frame(width: 10, height: 10)
            .scaleEffect(state == .connected && isPulsing ? 1.18 : 1.0)
            .shadow(color: state.color.opacity(state == .connected ? 0.4 : 0.18), radius: state == .connected ? 6 : 2, y: 1)
            .onAppear {
                updatePulse()
            }
            .onChange(of: state) { _, _ in
                updatePulse()
            }
    }

    private func updatePulse() {
        guard state == .connected else {
            withAnimation(.easeOut(duration: 0.2)) {
                isPulsing = false
            }
            return
        }

        isPulsing = false
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            isPulsing = true
        }
    }
}
