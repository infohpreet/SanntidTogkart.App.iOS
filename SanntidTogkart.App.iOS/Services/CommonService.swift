import Foundation

enum CommonService {
    static func isFreightTrainType(_ trainType: String?) -> Bool {
        let normalizedType = trainType?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        switch normalizedType {
        case "ONR", "MTAB", "GAG", "BASAB", "MTA", "ONRAIL", "RCT", "RCL", "GC", "HER", "GR", "TM", "HR", "PT":
            return true
        default:
            return false
        }
    }
}