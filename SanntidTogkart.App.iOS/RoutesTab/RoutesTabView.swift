import SwiftUI

struct RoutesTabView: View {
    @State private var viewModel = RoutesTabViewModel()
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.messages.isEmpty {
                    ProgressView("Laster togmeldinger...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = viewModel.errorMessage, viewModel.messages.isEmpty {
                    ContentUnavailableView(
                        "Kunne ikke hente togmeldinger",
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )
                } else if viewModel.filteredMessages.isEmpty {
                    ContentUnavailableView(
                        viewModel.searchText.isEmpty ? "Ingen togmeldinger" : "Ingen treff",
                        systemImage: "arrow.triangle.branch",
                        description: Text(
                            viewModel.searchText.isEmpty
                            ? "Ingen meldinger ble returnert for dagens dato."
                            : "Ingen togmeldinger matcher søket ditt."
                        )
                    )
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            summaryCard
                                .padding(.bottom, 14)

                            ForEach(Array(viewModel.filteredMessages.enumerated()), id: \.element.id) { index, message in
                                NavigationLink {
                                    TrainStationsView(
                                        trainMessage: message.trainMessage,
                                        title: "Togrute"
                                    )
                                } label: {
                                    routeRow(message, showsSeparator: index < viewModel.filteredMessages.count - 1)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 3)
                        .padding(.bottom, 12)
                        .appReadableContentWidth()
                    }
                    .refreshable {
                        await viewModel.refresh()
                    }
                }
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Ruter")
            .searchable(text: $searchText, prompt: "Søk etter tog eller rute")
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
                Text("Togruteoversikt")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text("Oppdatert oversikt over togmeldinger for i dag")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 3) {
                Text("\(viewModel.filteredMessages.count)")
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
                .fill(AppTheme.surface)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.border, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.04), radius: 10, y: 4)
    }

    private func routeRow(_ message: RouteMessage, showsSeparator: Bool) -> some View {
        HStack(alignment: .center, spacing: 12) {
            routeCountryFlagBadge(for: message)

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(message.routeNumberText)
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.primary)

                    Spacer(minLength: 8)

                    if let originTimeText = message.originTimeText {
                        Text(originTimeText)
                            .font(.subheadline.bold().monospacedDigit())
                            .foregroundStyle(.primary)
                    }
                }

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(message.origin ?? "Ukjent")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text("→")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.secondary)

                    Text(message.destination ?? "Ukjent")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                }

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(message.metadataLine)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    if !message.originDate.isEmpty {
                        Text(message.originDate)
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
        .overlay(alignment: .bottomLeading) {
            if showsSeparator {
                Rectangle()
                    .fill(AppTheme.border)
                    .frame(height: 1)
                    .padding(.leading, 56)
            }
        }
    }

    @ViewBuilder
    private func routeCountryFlagBadge(for message: RouteMessage) -> some View {
        switch message.countryCode.uppercased() {
        case "NO":
            RouteNorwayFlagBadge()
        case "SE":
            RouteSwedenFlagBadge()
        default:
            Image(systemName: "tram.fill")
                .font(.headline)
                .foregroundStyle(Color.accentColor)
                .frame(width: 42, height: 28)
                .background(AppTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

private extension RouteMessage {
    var routeNumberText: String {
        let normalizedLineNumber = lineNumber?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let normalizedTrainNo = trainNo.trimmingCharacters(in: .whitespacesAndNewlines)

        if !normalizedLineNumber.isEmpty && !normalizedTrainNo.isEmpty {
            return "\(normalizedLineNumber).\(normalizedTrainNo)"
        }

        if !normalizedLineNumber.isEmpty {
            return normalizedLineNumber
        }

        if !normalizedTrainNo.isEmpty {
            return normalizedTrainNo
        }

        return advertisementTrainNo
    }

    var originTimeText: String? {
        guard let originTime else {
            return nil
        }

        return AppTime.localTimeString(from: originTime)
    }

    var metadataLine: String {
        var parts: [String] = []

        if let trainType, !trainType.isEmpty {
            parts.append(trainType)
        }

        if let company, !company.isEmpty {
            parts.append(company)
        }

        return parts.joined(separator: " • ")
    }
}

private struct RouteNorwayFlagBadge: View {
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
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}

private struct RouteSwedenFlagBadge: View {
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
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}
