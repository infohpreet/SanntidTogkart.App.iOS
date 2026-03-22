import Foundation

struct AppSecrets: Decodable {
    let staging: EnvironmentSecrets
    let training: EnvironmentSecrets
    let prod: EnvironmentSecrets

    static let current = load()

    private static func load() -> AppSecrets {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "json") else {
            fatalError("Missing Secrets.json. Copy Secrets.example.json to Secrets.json and add your local credentials.")
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            return try decoder.decode(AppSecrets.self, from: data)
        } catch {
            fatalError("Unable to load Secrets.json: \(error.localizedDescription)")
        }
    }
}

struct EnvironmentSecrets: Decodable {
    let hubURL: URL
    let azureClientID: String
    let azureTenantID: String
    let azureClientSecret: String
}
