import Foundation
import Observation

struct FavoriteStation: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let shortName: String
    let plcCode: String?
    let lastUpdated: Date?
    let traseId: UUID?
    let isBorderStation: Bool
    let countryCode: String
    let latitude: Double?
    let longitude: Double?

    init(station: TraseStation) {
        self.id = station.id
        self.name = station.name
        self.shortName = station.shortName
        self.plcCode = station.plcCode
        self.lastUpdated = station.lastUpdated
        self.traseId = station.traseId
        self.isBorderStation = station.isBorderStation
        self.countryCode = station.countryCode
        self.latitude = station.latitude
        self.longitude = station.longitude
    }

    var station: TraseStation {
        TraseStation(
            id: id,
            name: name,
            shortName: shortName,
            plcCode: plcCode,
            lastUpdated: lastUpdated,
            traseId: traseId,
            isBorderStation: isBorderStation,
            countryCode: countryCode,
            latitude: latitude,
            longitude: longitude
        )
    }
}

@MainActor
@Observable
final class FavoriteStationsStore {
    static let shared = FavoriteStationsStore()

    var favorites: [FavoriteStation] = []

    private let defaultsKey = "favorite_stations"

    private init() {
        load()
    }

    func isFavorite(_ station: TraseStation) -> Bool {
        favorites.contains(where: { $0.id == station.id })
    }

    func toggle(_ station: TraseStation) {
        if let index = favorites.firstIndex(where: { $0.id == station.id }) {
            favorites.remove(at: index)
        } else {
            favorites.insert(FavoriteStation(station: station), at: 0)
        }
        persist()
    }

    func remove(_ favorite: FavoriteStation) {
        favorites.removeAll { $0.id == favorite.id }
        persist()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else {
            favorites = []
            return
        }

        do {
            favorites = try JSONDecoder().decode([FavoriteStation].self, from: data)
        } catch {
            favorites = []
        }
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(favorites)
            UserDefaults.standard.set(data, forKey: defaultsKey)
        } catch {
            UserDefaults.standard.removeObject(forKey: defaultsKey)
        }
    }
}
