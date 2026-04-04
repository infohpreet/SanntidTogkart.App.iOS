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

    init(
        id: UUID,
        name: String,
        shortName: String,
        plcCode: String?,
        lastUpdated: Date?,
        traseId: UUID?,
        isBorderStation: Bool,
        countryCode: String,
        latitude: Double?,
        longitude: Double?
    ) {
        self.id = id
        self.name = name
        self.shortName = shortName
        self.plcCode = plcCode
        self.lastUpdated = lastUpdated
        self.traseId = traseId
        self.isBorderStation = isBorderStation
        self.countryCode = countryCode
        self.latitude = latitude
        self.longitude = longitude
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

    var storageKey: String {
        Self.storageKey(shortName: shortName, countryCode: countryCode)
    }

    static func storageKey(shortName: String, countryCode: String) -> String {
        let normalizedShortName = shortName.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let normalizedCountryCode = countryCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return "\(normalizedCountryCode)::\(normalizedShortName)"
    }

    static let defaultFavorites: [FavoriteStation] = [
        FavoriteStation(
            id: UUID(uuidString: "5E9B8F54-11A5-4F81-9F2B-7D5D42000001") ?? UUID(),
            name: "OSL",
            shortName: "OSL",
            plcCode: "NO",
            lastUpdated: nil,
            traseId: nil,
            isBorderStation: false,
            countryCode: "NO",
            latitude: nil,
            longitude: nil
        ),
        FavoriteStation(
            id: UUID(uuidString: "5E9B8F54-11A5-4F81-9F2B-7D5D42000002") ?? UUID(),
            name: "Cst",
            shortName: "Cst",
            plcCode: "SE",
            lastUpdated: nil,
            traseId: nil,
            isBorderStation: false,
            countryCode: "SE",
            latitude: nil,
            longitude: nil
        )
    ]
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
        let key = favoriteKey(for: station)
        return favorites.contains(where: { $0.storageKey == key })
    }

    func toggle(_ station: TraseStation) {
        let key = favoriteKey(for: station)

        if let index = favorites.firstIndex(where: { $0.storageKey == key }) {
            favorites.remove(at: index)
        } else {
            favorites.insert(FavoriteStation(station: station), at: 0)
        }
        favorites = resolvedFavorites(from: favorites)
        persist()
    }

    func remove(_ favorite: FavoriteStation) {
        favorites.removeAll { $0.storageKey == favorite.storageKey }
        favorites = resolvedFavorites(from: favorites)
        persist()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else {
            favorites = FavoriteStation.defaultFavorites
            return
        }

        do {
            let decodedFavorites = try JSONDecoder().decode([FavoriteStation].self, from: data)
            favorites = resolvedFavorites(from: decodedFavorites)
        } catch {
            favorites = FavoriteStation.defaultFavorites
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

    private func favoriteKey(for station: TraseStation) -> String {
        FavoriteStation.storageKey(shortName: station.shortName, countryCode: station.countryCode)
    }

    private func deduplicatedFavorites(_ favorites: [FavoriteStation]) -> [FavoriteStation] {
        var seenKeys = Set<String>()
        return favorites.filter { favorite in
            seenKeys.insert(favorite.storageKey).inserted
        }
    }

    private func resolvedFavorites(from favorites: [FavoriteStation]) -> [FavoriteStation] {
        let deduplicated = deduplicatedFavorites(favorites)
        return deduplicated.isEmpty ? FavoriteStation.defaultFavorites : deduplicated
    }
}
