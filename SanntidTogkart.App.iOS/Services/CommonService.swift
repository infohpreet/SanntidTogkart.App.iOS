import Foundation

enum CommonService {
    static var freightTrainOperators: [String] {
        freightIdentifiers.sorted()
    }

    static func isFreightTrainCompany(_ company: String?) -> Bool {
        let normalizedCompany = normalizedUppercased(company)

        guard let normalizedCompany, !normalizedCompany.isEmpty else {
            return false
        }

        return freightIdentifiers.contains(normalizedCompany)
    }

    static func isTrainMessageMappedStationCode(_ value: String?) -> Bool {
        let normalizedValue = normalizedUppercased(value)

        guard let normalizedValue, !normalizedValue.isEmpty else {
            return false
        }

        return trainMessageStationCodeMappings.keys.contains(normalizedValue)
    }

    static func isIgnoredNearestStationCode(_ value: String?) -> Bool {
        let normalizedValue = normalizedUppercased(value)

        guard let normalizedValue, !normalizedValue.isEmpty else {
            return false
        }

        return nearestStationIgnoredCodes.contains(normalizedValue)
    }

    static func isIgnoredNearestStation(_ station: TraseStation) -> Bool {
        isIgnoredNearestStationCode(station.shortName)
    }

    static func remappedTrainMessageStationCode(for value: String?) -> String? {
        guard let value else {
            return nil
        }

        guard let normalizedCode = normalizedUppercased(value), !normalizedCode.isEmpty else {
            return value
        }

        return trainMessageStationCodeMappings[normalizedCode] ?? value
    }

    private static func normalizedUppercased(_ value: String?) -> String? {
        value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
    }
}

private let freightIdentifiers: Set<String> = [
    "ABCD", "BLSRAIL", "ONR", "MTAB", "CN", "BASAB", "MTA", "ONRAIL", "RCT", "RCL", "GC", "HER", "GR", "BN", "TM", "HR", "PT"
]

private let trainMessageStationCodeMappings: [String: String] = [
    "LOD": "OSL",
    "SUD": "DRM",
    "KVB": "STV",
    "BES": "SKØ",
    "JAH": "JAR"
]

private let nearestStationIgnoredCodes: Set<String> = [
    "LOD", "SUD", "KVB", "BES", "JAH", "LOE"
]