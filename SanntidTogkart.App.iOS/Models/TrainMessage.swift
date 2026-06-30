import Foundation

struct TrainMessage: Codable, Identifiable, Sendable {
    let id: Int
    let countryCode: String
    let messageKey: String
    let advertisementTrainNo: String
    let trainNo: String
    let originDate: String
    let originTime: Date?
    var origin: String?
    var destination: String?
    let trainType: String?
    let lineNumber: String?
    let company: String?
    let scheduled: Bool?
    let trainLocation: TrainLocation?
    let createdAt: Date
    let lastUpdatedAt: Date
}
