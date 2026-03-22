import Foundation

struct TrainMetrics: Codable, Sendable {
    let trainStationsCountNO: Int
    let trainStationsCountSE: Int
    let trainMessagesCountNO: Int
    let trainMessagesCountSE: Int

    private enum CodingKeys: String, CodingKey {
        case trainStationsCountNO
        case trainStationsCountSE
        case trainMessagesCountNO
        case trainMessagesCountSE
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        trainStationsCountNO = try container.decode(Int.self, forKey: .trainStationsCountNO)
        trainStationsCountSE = try container.decode(Int.self, forKey: .trainStationsCountSE)
        trainMessagesCountNO = try container.decode(Int.self, forKey: .trainMessagesCountNO)
        trainMessagesCountSE = try container.decode(Int.self, forKey: .trainMessagesCountSE)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(trainStationsCountNO, forKey: .trainStationsCountNO)
        try container.encode(trainStationsCountSE, forKey: .trainStationsCountSE)
        try container.encode(trainMessagesCountNO, forKey: .trainMessagesCountNO)
        try container.encode(trainMessagesCountSE, forKey: .trainMessagesCountSE)
    }
}
