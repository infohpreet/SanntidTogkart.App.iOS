import SwiftUI

struct StationsTabView: View {
    @State private var viewModel = StationsTabViewModel()
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.stations.isEmpty {
                    ProgressView("Laster stasjoner...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = viewModel.errorMessage, viewModel.stations.isEmpty {
                    ContentUnavailableView(
                        "Kunne ikke hente stasjoner",
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )
                } else if viewModel.filteredStations.isEmpty {
                    ContentUnavailableView(
                        viewModel.searchText.isEmpty ? "Ingen stasjoner" : "Ingen treff",
                        systemImage: "building.columns.fill",
                        description: Text(
                            viewModel.searchText.isEmpty
                            ? "Ingen stasjoner ble returnert fra FeedHub."
                            : "Ingen stasjoner matcher søket ditt."
                        )
                    )
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            summaryCard
                                .padding(.bottom, 14)

                            ForEach(Array(viewModel.filteredStations.enumerated()), id: \.element.id) { index, station in
                                NavigationLink {
                                    StationMessagesView(station: station)
                                } label: {
                                    stationRow(station)
                                }
                                .buttonStyle(.plain)

                                if index < viewModel.filteredStations.count - 1 {
                                    Divider()
                                        .padding(.leading, 56)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 3)
                        .padding(.bottom, 12)
                    }
                    .refreshable {
                        await viewModel.refresh()
                    }
                }
            }
            .navigationTitle("Stasjoner")
            .searchable(text: $searchText, prompt: "Søk etter stasjon")
        }
        .task {
            await viewModel.start()
        }
        .onChange(of: searchText) { _, newValue in
            viewModel.updateSearchText(newValue)
        }
    }

    private var summaryCard: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Stasjonsoversikt")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text("Oppdatert oversikt over stasjoner i FeedHub")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 3) {
                Text("\(viewModel.filteredStations.count)")
                    .font(.title3.monospacedDigit().weight(.bold))
                    .foregroundStyle(.primary)

                Text("treff")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [Color(.secondarySystemBackground), Color(.systemBackground)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.04), radius: 10, y: 4)
    }

    private func stationRow(_ station: TraseStation) -> some View {
        HStack(alignment: .center, spacing: 12) {
            countryFlagBadge(for: station)

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .center, spacing: 8) {
                    Text(station.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if station.isBorderStation {
                        Text("Grense")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.orange.opacity(0.10), in: Capsule())
                    }

                    Spacer(minLength: 0)
                }

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(station.secondaryMetadataLine)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    if let coordinatesText = station.coordinatesText {
                        Text(coordinatesText)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                }
            }
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func countryFlagBadge(for station: TraseStation) -> some View {
        Group {
            switch station.countryCode.uppercased() {
            case "NO":
                NorwayFlagBadge()
            case "SE":
                SwedenFlagBadge()
            default:
                Image(systemName: "building.columns.fill")
                    .font(.headline)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 42, height: 28)
                    .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

private extension TraseStation {
    var secondaryMetadataLine: String {
        let trimmedShortName = shortName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPlcCode = plcCode?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return [trimmedShortName, trimmedPlcCode]
            .filter { !$0.isEmpty }
            .joined(separator: " • ")
    }

    var coordinatesText: String? {
        guard let latitude, let longitude else {
            return nil
        }

        return String(format: "%.5f, %.5f", latitude, longitude)
    }
}

private struct NorwayFlagBadge: View {
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

private struct SwedenFlagBadge: View {
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
