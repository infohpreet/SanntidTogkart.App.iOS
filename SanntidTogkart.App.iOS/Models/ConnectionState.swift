import Foundation
import SwiftUI

enum ConnectionState: Sendable {
    case disconnected
    case connecting
    case connected
    case reconnecting
    case failed
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
