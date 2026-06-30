import CoreLocation
import Foundation

struct TrainLocation: Codable, Sendable {
    let countryCode: String
    let createdAt: Date
    let id: Int
    let latitude: Decimal?
    let longitude: Decimal?
    let serviceTime: Date
    let trainNumber: String

    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else {
            return nil
        }

        return CLLocationCoordinate2D(
            latitude: NSDecimalNumber(decimal: latitude).doubleValue,
            longitude: NSDecimalNumber(decimal: longitude).doubleValue
        )
    }
}
