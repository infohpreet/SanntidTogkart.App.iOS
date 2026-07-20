import Foundation
import Observation

struct TrainListStationFilter: Sendable {
    let lineNumbers: Set<String>
    let tracks: Set<String>
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
                lineNumbers: persistedFilter.lineNumbers,
                tracks: persistedFilter.tracks
            )
        }

        // Backward compatibility for filters saved before key canonicalization.
        guard let persistedFilter = filtersByStationKey[stationKey] else {
            return TrainListStationFilter(lineNumbers: [], tracks: [])
        }

        return TrainListStationFilter(
            lineNumbers: persistedFilter.lineNumbers,
            tracks: persistedFilter.tracks
        )
    }

    func setFilter(for stationKey: String, lineNumbers: Set<String>, tracks: Set<String>) {
        let canonicalKey = canonicalStationKey(from: stationKey)
        let normalizedLineNumbers = normalizedSet(lineNumbers)
        let normalizedTracks = normalizedSet(tracks)

        if normalizedLineNumbers.isEmpty, normalizedTracks.isEmpty {
            filtersByStationKey.removeValue(forKey: canonicalKey)
            filtersByStationKey.removeValue(forKey: stationKey)
        } else {
            let persistedFilter = PersistedStationFilter(
                lineNumbers: normalizedLineNumbers,
                tracks: normalizedTracks
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

    private func normalizedSet(_ values: Set<String>) -> Set<String> {
        Set(values.compactMap { normalizedText($0) })
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
    let lineNumbers: Set<String>
    let tracks: Set<String>
}

/// Shared matching rules for the train list line/track filters, used by both the
/// `TrainListView` filter dropdown and the home screen favorite station cards so the two
/// surfaces can never drift out of sync.
enum TrainListFilterMatching {
    static func normalizedFilterSet(_ values: Set<String>) -> Set<String> {
        Set(values.compactMap { normalizedText($0) })
    }

    static func matches(lineValue: String?, trackValue: String?, lineNumberFilters: Set<String>, trackFilters: Set<String>) -> Bool {
        let normalizedLineFilters = normalizedFilterSet(lineNumberFilters)
        let normalizedTrackFilters = normalizedFilterSet(trackFilters)

        if !normalizedLineFilters.isEmpty {
            guard let lineValue,
                  normalizedLineFilters.contains(where: { $0.localizedCaseInsensitiveCompare(lineValue) == .orderedSame }) else {
                return false
            }
        }

        if !normalizedTrackFilters.isEmpty {
            guard let trackValue,
                  normalizedTrackFilters.contains(where: { $0.localizedCaseInsensitiveCompare(trackValue) == .orderedSame }) else {
                return false
            }
        }

        return true
    }

    static func normalizedText(_ value: String?) -> String? {
        let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return normalized.isEmpty ? nil : normalized
    }
}
