import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class FavoriteTabViewModel {
    var metrics: TrainMetrics?
    var errorMessage: String?
    var isLoading = false
    var connectionState: ConnectionState = .disconnected
    var connectionDetails = "Ikke tilkoblet."
    var lastUpdated: Date?
    var liveTrainMessages: [TrainMessage] = []

    var lastUpdatedText: String? {
        guard let lastUpdated else {
            return nil
        }

        return lastUpdated.formatted(date: .abbreviated, time: .standard)
    }

    var totalLiveTrainCount: Int {
        liveTrainMessages.count
    }

    var operatorCounts: [OperatorTrainCount] {
        Dictionary(grouping: liveTrainMessages) { trainMessage in
            let normalizedCompany = displayCompany(for: trainMessage) ?? "Operatør mangler"
            return normalizedCompany
        }
        .map { OperatorTrainCount(name: $0.key, count: $0.value.count) }
        .sorted { lhs, rhs in
            if lhs.count == rhs.count {
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }

            return lhs.count > rhs.count
        }
    }

    var trainTypeCounts: [OperatorTrainCount] {
        Dictionary(grouping: liveTrainMessages) { trainMessage in
            let trainType = normalizedText(trainMessage.trainType) ?? ""
            return trainType.isEmpty ? "Togtype mangler" : trainType
        }
        .map { OperatorTrainCount(name: $0.key, count: $0.value.count) }
        .sorted { lhs, rhs in
            if lhs.count == rhs.count {
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }

            return lhs.count > rhs.count
        }
    }

    private let service: SignalRService
    private var hasStarted = false

    init() {
        self.service = SignalRService()
        configureBindings()
    }

    init(service: SignalRService) {
        self.service = service
        configureBindings()
    }

    private func configureBindings() {
        self.service.onMetrics = { [weak self] metrics in
            guard let self else {
                return
            }

            self.metrics = metrics
            self.isLoading = false
            self.errorMessage = nil
            self.lastUpdated = Date()
            self.connectionDetails = "TrainMetrics mottatt fra FeedHub."
        }
        self.service.onLiveTrainMessages = { [weak self] trainMessages in
            guard let self else {
                return
            }

            self.liveTrainMessages = trainMessages
            self.lastUpdated = Date()
        }
        self.service.onStateChange = { [weak self] state in
            guard let self else {
                return
            }

            self.connectionState = state
            if state != .failed {
                self.connectionDetails = state.description
            }
        }
        self.service.onError = { [weak self] message in
            guard let self else {
                return
            }

            self.errorMessage = message
            self.isLoading = false
            self.connectionDetails = message
        }
    }

    func start() async {
        guard !hasStarted else {
            return
        }

        hasStarted = true
        isLoading = true
        await service.start()
        await service.requestTrainMetrics()
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil
        await service.requestTrainMetrics()
    }

    func stop() {
        hasStarted = false
        service.stop()
    }

    private func displayCompany(for trainMessage: TrainMessage) -> String? {
        normalizedText(trainMessage.company)
            ?? normalizedText(trainMessage.trainPosition?.toc)
            ?? normalizedText(trainMessage.trainPosition?.geoJson.properties.operatorRef)
    }

    private func normalizedText(_ value: String?) -> String? {
        let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return normalized.isEmpty ? nil : normalized
    }
}

struct OperatorTrainCount: Identifiable, Hashable {
    let name: String
    let count: Int

    var id: String { name }
}

extension ConnectionState {
    var shortLabel: String {
        switch self {
        case .disconnected:
            return "Offline"
        case .connecting:
            return "Kobler"
        case .connected:
            return "Live"
        case .reconnecting:
            return "Prøver igjen"
        case .failed:
            return "Feil"
        }
    }

    var description: String {
        switch self {
        case .disconnected:
            return "Frakoblet"
        case .connecting:
            return "Kobler til"
        case .connected:
            return "Tilkoblet"
        case .reconnecting:
            return "Kobler til på nytt"
        case .failed:
            return "Feilet"
        }
    }

    var color: Color {
        switch self {
        case .disconnected:
            return .gray
        case .connecting, .reconnecting:
            return .orange
        case .connected:
            return .green
        case .failed:
            return .red
        }
    }
}
