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
                            : "Ingen togmeldinger matcher soket ditt."
                        )
                    )
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            routeMessagesBoard
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 16)
                        .appReadableContentWidth()
                    }
                    .scrollIndicators(.hidden)
                    .refreshable {
                        await viewModel.refresh()
                    }
                }
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Tog")
            .searchable(text: $searchText, prompt: "Sok etter tog eller rute")
        }
        .task {
            await viewModel.start()
        }
        .onChange(of: searchText) { _, newValue in
            viewModel.updateSearchText(newValue)
        }
    }

    private var routeMessagesBoard: some View {
        let messages = viewModel.filteredMessages

        return LazyVStack(spacing: 0) {
            boardHeader

            ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                NavigationLink {
                    TrainRouteView(trainMessage: message.trainMessage)
                } label: {
                    routeRow(message)
                }
                .buttonStyle(.plain)

                if index < messages.count - 1 {
                    Rectangle()
                        .fill(RoutesBoardStyle.divider)
                        .frame(height: 1)
                        .padding(.horizontal, 18)
                }
            }
        }
        .background(RoutesBoardStyle.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var boardHeader: some View {
        VStack(spacing: 10) {
            Rectangle()
                .fill(RoutesBoardStyle.divider)
                .frame(height: 1)

            HStack(spacing: 10) {
                Text("Avgang")
                    .frame(width: 56, alignment: .leading)

                Color.clear
                    .frame(width: 58, height: 1)

                Text("Tog fra")
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("Tog til")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(RoutesBoardStyle.mutedText)
            .padding(.horizontal, 18)
        }
        .padding(.bottom, 6)
    }

    private func routeRow(_ message: RouteMessage) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Text(message.originTimeText ?? "--:--")
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .foregroundStyle(.primary)
                .frame(width: 56, alignment: .leading)

            routeBadge(for: message)

            Text(message.origin ?? "Ukjent")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(message.destination ?? "Ukjent")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func routeBadge(for message: RouteMessage) -> some View {
        let isFreightTrain = CommonService.isFreightTrainCompany(message.company)

        return Text(message.routeNumberText)
            .font(.subheadline.monospacedDigit().weight(.bold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(width: 58, height: 26)
            .background(
                isFreightTrain ? RoutesBoardStyle.freightGreen : RoutesBoardStyle.trainRed,
                in: RoundedRectangle(cornerRadius: 1)
            )
    }
}

private extension RouteMessage {
    var routeNumberText: String {
        let normalizedLineNumber = lineNumber?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let normalizedTrainNo = trainNo.trimmingCharacters(in: .whitespacesAndNewlines)

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
}

private enum RoutesBoardStyle {
    static let background = AppTheme.surface
    static let divider = AppTheme.border
    static let mutedText = Color.secondary
    static let freightGreen = Color(red: 0.17, green: 0.52, blue: 0.29)
    static let trainRed = Color(red: 0.90, green: 0.06, blue: 0.12)
}
