import Foundation

struct TrainPosition: Codable, Sendable {
    let country: String
    let toc: String
    let timestamp: Date
    let geoJson: GeoJson
}

struct GeoJson: Codable, Sendable {
    let type: String
    let geometry: Geometry
    let properties: GeoJsonProperties
}

struct Geometry: Codable, Sendable {
    let type: String
    let coordinates: [Double]
}

struct GeoJsonProperties: Codable, Sendable {
    let trainNumber: String
    let originDate: String?
    let wagonId: String?
    let operatorRef: String
    let serviceTime: Date
    let satelliteCount: Int?
    let speedKph: Double?
    let bearingDegrees: Double?
}
