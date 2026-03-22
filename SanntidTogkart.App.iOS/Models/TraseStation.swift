import Foundation

struct TraseStation: Codable, Identifiable, Sendable {
    let id: UUID
    let name: String
    let shortName: String
    let plcCode: String?
    let lastUpdated: Date?
    let traseId: UUID?
    let isBorderStation: Bool
    let countryCode: String
    let latitude: Double?
    let longitude: Double?
}
