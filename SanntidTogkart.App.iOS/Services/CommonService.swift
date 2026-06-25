import Foundation

enum CommonService {
    static func isFreightTrainType(_ trainType: String?) -> Bool {
        let normalizedType = trainType?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        switch normalizedType {
        case "GT", "SPFG", "CN", "HR", "GC", "MTAB", "ONRAIL":
            return true
        default:
            return false
        }
    }
}