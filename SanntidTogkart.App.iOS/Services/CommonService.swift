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

    static func isTrainMessageMappedStationCode(_ value: String?) -> Bool {
        let normalizedValue = value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        guard let normalizedValue, !normalizedValue.isEmpty else {
            return false
        }

        return trainMessageStationCodeMappings.keys.contains(normalizedValue)
    }

    static func remappedTrainMessageStationCode(for value: String?) -> String? {
        guard let value else {
            return nil
        }

        let normalizedCode = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalizedCode.isEmpty else {
            return value
        }

        return trainMessageStationCodeMappings[normalizedCode] ?? value
    }
}

private let freightIdentifiers: Set<String> = [
    "ABCD", "BLSRAIL", "ONR", "MTAB", "CN", "BASAB", "MTA", "ONRAIL", "RCT", "RCL", "GC", "HER", "GR", "TM", "HR", "PT"
]

private let trainMessageStationCodeMappings: [String: String] = [
    "LOD": "OSL",
    "SUD": "DRM",
    "KVB": "STV",
    "BES": "SKØ",
    "JAH": "JAR"
]