import Foundation

struct AuthSignalRSecrets: Decodable {
    let staging: EnvironmentSecrets
    let training: EnvironmentSecrets
    let prod: EnvironmentSecrets

    static let current = load()

    private static func load() -> AuthSignalRSecrets {
        guard let url = Bundle.main.url(forResource: "AuthSignalR", withExtension: "json") else {
            fatalError("Missing AuthSignalR.json. Add environment credentials for SignalR authentication.")
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            return try decoder.decode(AuthSignalRSecrets.self, from: data)
        } catch {
            fatalError("Unable to load AuthSignalR.json: \(error.localizedDescription)")
        }
    }
}

struct AuthLoginSecrets: Decodable {
    let authLogin: EnvironmentSecrets

    static let current = load()

    private static func load() -> AuthLoginSecrets {
        guard let url = Bundle.main.url(forResource: "AuthLogin", withExtension: "json") else {
            fatalError("Missing AuthLogin.json. Add SSO credentials for login.")
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            return try decoder.decode(AuthLoginSecrets.self, from: data)
        } catch {
            fatalError("Unable to load AuthLogin.json: \(error.localizedDescription)")
        }
    }
}

struct EnvironmentSecrets: Decodable {
    let hubURL: URL
    let azureClientID: String
    let azureTenantID: String
    let azureClientSecret: String
}
