import Foundation

enum CommonService {
    static func isFreightTrainCompany(_ company: String?) -> Bool {
        let normalizedCompany = company?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        guard let normalizedCompany, !normalizedCompany.isEmpty else {
            return false
        }

        return freightIdentifiers.contains(normalizedCompany)
    }
}

private let freightIdentifiers: Set<String> = [
    "ABCD", "BLSRAIL", "ONR", "MTAB", "CN", "BASAB", "MTA", "ONRAIL", "RCT", "RCL", "GC", "HER", "GR", "TM", "HR", "PT"
]