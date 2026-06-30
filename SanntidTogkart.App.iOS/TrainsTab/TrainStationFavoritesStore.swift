import Foundation
import Observation

@MainActor
@Observable
final class TrainStationFavoritesStore {
    static let shared = TrainStationFavoritesStore()

    private(set) var stations: [TraseStation] = []

    private let defaultsKey = "train_station_favorites"

    private init() {
        load()
    }

    func isFavorite(_ station: TraseStation) -> Bool {
        let key = station.storageKey
        return stations.contains { $0.storageKey == key }
    }

    func toggle(_ station: TraseStation) {
        let key = station.storageKey

        if let index = stations.firstIndex(where: { $0.storageKey == key }) {
            stations.remove(at: index)
        } else {
            stations.insert(station, at: 0)
        }

        persist()
    }

    func remove(_ station: TraseStation) {
        let key = station.storageKey
        guard let index = stations.firstIndex(where: { $0.storageKey == key }) else {
            return
        }

        stations.remove(at: index)
        persist()
    }

    func moveStation(
        draggedStorageKey: String,
        to targetStorageKey: String,
        placeAfterTarget: Bool = false
    ) {
        guard
            draggedStorageKey != targetStorageKey,
            let fromIndex = stations.firstIndex(where: { $0.storageKey == draggedStorageKey }),
            stations.contains(where: { $0.storageKey == targetStorageKey })
        else {
            return
        }

        var updatedStations = stations
        let draggedStation = updatedStations.remove(at: fromIndex)

        guard let adjustedTargetIndex = updatedStations.firstIndex(where: { $0.storageKey == targetStorageKey }) else {
            return
        }

        let baseInsertionIndex = placeAfterTarget ? adjustedTargetIndex + 1 : adjustedTargetIndex
        let insertionIndex = min(max(0, baseInsertionIndex), updatedStations.count)

        updatedStations.insert(draggedStation, at: insertionIndex)

        stations = updatedStations
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
