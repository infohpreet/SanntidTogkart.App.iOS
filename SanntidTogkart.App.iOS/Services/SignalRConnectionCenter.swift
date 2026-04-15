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
    var lastHandshake: SignalRHandshakeInfo?

    var accessibilityStatusText: String {
        if let lastUpdated {
            return "\(state.description), oppdatert \(AppTime.localTimeString(from: lastUpdated))"
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

    func updateHandshake(_ handshake: SignalRHandshakeInfo) {
        lastHandshake = handshake
        lastUpdated = Date()
    }

    func clearHandshake() {
        lastHandshake = nil
    }
}
