import Foundation

enum ConnectionState: Sendable {
    case disconnected
    case connecting
    case connected
    case reconnecting
    case failed
}
