import Foundation

extension TraseStation {
    var displayShortNameLine: String {
        let trimmedShortName = shortName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPlcCode = plcCode?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        var parts: [String] = []

        if !trimmedShortName.isEmpty {
            parts.append(trimmedShortName)
        }

        if !trimmedPlcCode.isEmpty {
            parts.append(trimmedPlcCode)
        }

        return parts.joined(separator: " • ")
    }
}
