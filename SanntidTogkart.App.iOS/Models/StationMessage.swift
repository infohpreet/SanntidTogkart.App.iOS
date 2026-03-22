import Foundation

struct StationMessage: Codable, Identifiable {
    let activity: String
    let activityKind: String?
    let ata: Date?
    let atd: Date?
    let city: String
    let countryCode: String
    let createdAt: Date
    let eta: Date?
    let etd: Date?
    let id: Int
    let lastUpdatedAt: Date
    let messageKey: String
    let originDate: String
    let originTime: Date?
    let scheduled: Bool?
    let scheduledTrack: String?
    let sta: Date?
    let std: Date?
    let trainKind: String?
    let trainNo: String
    let visitId: String?
}
