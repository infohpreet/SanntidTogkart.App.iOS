import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class SignalRConnectionCenter {
    static let shared = SignalRConnectionCenter()

    var state: ConnectionState = .disconnected
    var details = "Ikke tilkoblet."
    var lastUpdated: Date?

    var accessibilityStatusText: String {
        if let lastUpdated {
            return "\(state.description), oppdatert \(lastUpdated.formatted(date: .omitted, time: .shortened))"
        }

        return state.description
    }

    private init() {}

    func update(state: ConnectionState, details: String? = nil) {
        self.state = state
        if let details {
            self.details = details
        } else {
            self.details = state.description
        }
        self.lastUpdated = Date()
    }
}
