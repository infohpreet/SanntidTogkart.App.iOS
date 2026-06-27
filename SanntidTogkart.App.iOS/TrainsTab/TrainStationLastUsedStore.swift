import Foundation
import Observation

@MainActor
@Observable
final class TrainStationLastUsedStore {
    static let shared = TrainStationLastUsedStore()

    private(set) var stations: [TraseStation] = []

    private let defaultsKey = "train_station_last_used"

    private init() {
        load()
    }

    func record(_ station: TraseStation) {
        let key = station.storageKey
        stations.removeAll { $0.storageKey == key }
        stations.insert(station, at: 0)
        persist()
    }

    func clear() {
        stations = []
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }

    func remove(_ station: TraseStation) {
        let key = station.storageKey
        guard let index = stations.firstIndex(where: { $0.storageKey == key }) else {
            return
        }

        stations.remove(at: index)
        persist()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else {
            stations = []
            return
        }

        do {
            let decodedStations = try JSONDecoder().decode([TraseStation].self, from: data)
            stations = deduplicated(decodedStations)
        } catch {
            stations = []
        }
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(stations)
            UserDefaults.standard.set(data, forKey: defaultsKey)
        } catch {
            UserDefaults.standard.removeObject(forKey: defaultsKey)
        }
    }

    private func deduplicated(_ stations: [TraseStation]) -> [TraseStation] {
        var seenKeys = Set<String>()
        return stations.filter { station in
            seenKeys.insert(station.storageKey).inserted
        }
    }
}
