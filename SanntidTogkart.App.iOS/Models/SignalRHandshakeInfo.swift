import Foundation

struct SignalRHandshakeInfo: Decodable, Sendable {
    let message: String
    let connectionId: String
    let timestamp: Date
}
