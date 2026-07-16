import Foundation
import Observation

struct TrainListStationFilter: Sendable {
    let lineNumber: String?
    let track: String?
}

@MainActor
@Observable
final class TrainListStationFilterStore {
    static let shared = TrainListStationFilterStore()

    private(set) var version = 0

    private let defaultsKey = "train_list_station_filters"
    private var filtersByStationKey: [String: PersistedStationFilter] = [:]

    private init() {
        load()
    }

    func filter(for stationKey: String) -> TrainListStationFilter {
        let canonicalKey = canonicalStationKey(from: stationKey)

        if let persistedFilter = filtersByStationKey[canonicalKey] {
            return TrainListStationFilter(
                lineNumber: persistedFilter.lineNumber,
                track: persistedFilter.track
            )
        }

        // Backward compatibility for filters saved before key canonicalization.
        guard let persistedFilter = filtersByStationKey[stationKey] else {
            return TrainListStationFilter(lineNumber: nil, track: nil)
        }

        return TrainListStationFilter(
            lineNumber: persistedFilter.lineNumber,
            track: persistedFilter.track
        )
    }

    func setFilter(for stationKey: String, lineNumber: String?, track: String?) {
        let canonicalKey = canonicalStationKey(from: stationKey)
        let normalizedLineNumber = normalizedText(lineNumber)
        let normalizedTrack = normalizedText(track)

        if normalizedLineNumber == nil, normalizedTrack == nil {
            filtersByStationKey.removeValue(forKey: canonicalKey)
            filtersByStationKey.removeValue(forKey: stationKey)
        } else {
            let persistedFilter = PersistedStationFilter(
                lineNumber: normalizedLineNumber,
                track: normalizedTrack
            )

            filtersByStationKey[canonicalKey] = persistedFilter

            if canonicalKey != stationKey {
                filtersByStationKey.removeValue(forKey: stationKey)
            }
        }

        version += 1
        persist()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else {
            filtersByStationKey = [:]
            return
        }

        do {
            filtersByStationKey = try JSONDecoder().decode([String: PersistedStationFilter].self, from: data)
            version += 1
        } catch {
            filtersByStationKey = [:]
        }
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(filtersByStationKey)
            UserDefaults.standard.set(data, forKey: defaultsKey)
        } catch {
            UserDefaults.standard.removeObject(forKey: defaultsKey)
        }
    }

    private func normalizedText(_ value: String?) -> String? {
        let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return normalized.isEmpty ? nil : normalized
    }

    private func canonicalStationKey(from stationKey: String) -> String {
        let trimmedKey = stationKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let components = trimmedKey.split(separator: "::", maxSplits: 1, omittingEmptySubsequences: false)

        guard components.count == 2 else {
            return trimmedKey.uppercased()
        }

        let countryCode = String(components[0]).trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let shortName = String(components[1]).trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let remappedShortName = CommonService.remappedTrainMessageStationCode(for: shortName)
            .flatMap { normalizedText($0) }?
            .uppercased() ?? shortName

        return "\(countryCode)::\(remappedShortName)"
    }
}

private struct PersistedStationFilter: Codable {
    let lineNumber: String?
    let track: String?
}
