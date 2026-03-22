import Observation
import SwiftUI

struct HomeTabView: View {
    @State private var viewModel = HomeTabViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    metricsSection
                    operatorSection
                }
                .padding(20)
            }
            .refreshable {
                await viewModel.refresh()
            }
            .navigationTitle("Sanntid Togkart")
        }
        .task {
            await viewModel.start()
        }
    }

    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Oversikt")
                    .font(.title3.weight(.semibold))

                Spacer()

                if viewModel.isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if let metrics = viewModel.metrics {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    metricCard(
                        title: "Stasjoner",
                        value: "\(metrics.trainStationsCountNO)",
                        countryCode: "NO"
                    )
                    metricCard(
                        title: "Stasjoner",
                        value: "\(metrics.trainStationsCountSE)",
                        countryCode: "SE"
                    )
                    metricCard(
                        title: "Togruter",
                        value: "\(metrics.trainMessagesCountNO)",
                        countryCode: "NO"
                    )
                    metricCard(
                        title: "Togruter",
                        value: "\(metrics.trainMessagesCountSE)",
                        countryCode: "SE"
                    )
                }

            } else if let errorMessage = viewModel.errorMessage {
                ContentUnavailableView(
                    "Kunne ikke hente trainmetrics",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )
            } else {
                ContentUnavailableView(
                    "Ingen data ennå",
                    systemImage: "chart.bar",
                    description: Text("Kobler til FeedHub og venter på første respons.")
                )
            }
        }
    }

    private var operatorSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text("Aktive tog")
                    .font(.title3.weight(.semibold))

                Spacer()

                HomeConnectionStatusDot(state: viewModel.connectionState)
            }

            if viewModel.totalLiveTrainCount == 0 {
                ContentUnavailableView(
                    "Ingen aktive tog ennå",
                    systemImage: "tram.fill",
                    description: Text("Venter på live posisjonsdata fra FeedHub.")
                )
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    totalTrainTile

                    trainCountGroup(
                        title: "Operatører",
                        items: viewModel.operatorCounts
                    )

                    trainCountGroup(
                        title: "Togtyper",
                        items: viewModel.trainTypeCounts
                    )
                }
            }
        }
    }

    private func trainCountGroup(title: String, items: [OperatorTrainCount]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(items) { item in
                    operatorTile(item)
                }
            }
        }
    }

    private var totalTrainTile: some View {
        HStack(alignment: .center, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "tram.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentColor)

                Text("Totalt")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Text("\(viewModel.totalLiveTrainCount)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(
            LinearGradient(
                colors: [Color.accentColor.opacity(0.10), Color.accentColor.opacity(0.03)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.accentColor.opacity(0.14), lineWidth: 1)
        }
    }

    private func operatorTile(_ item: OperatorTrainCount) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Text(item.name)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 8)

            Text("\(item.count)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            LinearGradient(
                colors: [Color(.secondarySystemBackground), Color(.tertiarySystemBackground)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
        }
    }

    private func metricCard(title: String, value: String, countryCode: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            MetricCountryFlagBadge(countryCode: countryCode)

            VStack(alignment: .trailing, spacing: 4) {
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(
            LinearGradient(
                colors: [Color(.secondarySystemBackground), Color(.tertiarySystemBackground)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
        }
    }
}

private struct HomeConnectionStatusDot: View {
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

private struct MetricCountryFlagBadge: View {
    let countryCode: String

    var body: some View {
        Group {
            switch countryCode.uppercased() {
            case "NO":
                HomeNorwayFlagBadge()
            case "SE":
                HomeSwedenFlagBadge()
            default:
                Rectangle()
                    .fill(Color(.tertiarySystemBackground))
                    .frame(width: 42, height: 28)
            }
        }
    }
}

private struct HomeNorwayFlagBadge: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color(red: 0.73, green: 0.11, blue: 0.17))

            Rectangle()
                .fill(.white)
                .frame(width: 7)
                .offset(x: -7)

            Rectangle()
                .fill(.white)
                .frame(height: 7)

            Rectangle()
                .fill(Color(red: 0.0, green: 0.13, blue: 0.36))
                .frame(width: 4)
                .offset(x: -7)

            Rectangle()
                .fill(Color(red: 0.0, green: 0.13, blue: 0.36))
                .frame(height: 4)
        }
        .frame(width: 42, height: 28)
    }
}

private struct HomeSwedenFlagBadge: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color(red: 0.0, green: 0.32, blue: 0.61))

            Rectangle()
                .fill(Color(red: 0.98, green: 0.80, blue: 0.17))
                .frame(width: 6)
                .offset(x: -7)

            Rectangle()
                .fill(Color(red: 0.98, green: 0.80, blue: 0.17))
                .frame(height: 6)
        }
        .frame(width: 42, height: 28)
    }
}

#Preview {
    HomeTabView()
}
