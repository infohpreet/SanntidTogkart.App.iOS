import Foundation

enum AuthConfig {
    static var currentEnvironment: AppEnvironment {
        get {
            let storedValue = UserDefaults.standard.string(forKey: StorageKeys.environment)
            return AppEnvironment(rawValue: storedValue ?? "") ?? .staging
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: StorageKeys.environment)
        }
    }

    static var current: EnvironmentConfiguration {
        currentEnvironment.configuration
    }

    static var hubURL: URL { current.hubURL }
    static var azureClientID: String { current.azureClientID }
    static var azureTenantID: String { current.azureTenantID }
    static var azureClientSecret: String { current.azureClientSecret }
    static var entraAuthorizeURL: URL { current.entraAuthorizeURL }
    static var entraTokenURL: URL { current.entraTokenURL }
    static let ssoCallbackScheme = "sanntidtogkart"
    static let ssoRedirectURI = "\(ssoCallbackScheme)://auth"
    static let ssoScopes = [
        "openid",
        "profile",
        "offline_access",
        "User.Read"
    ]

    private enum StorageKeys {
        static let environment = "app.environment"
    }
}

enum AppEnvironment: String, CaseIterable, Identifiable {
    case staging
    case training
    case prod

    var id: String { rawValue }

    var title: String {
        switch self {
        case .staging:
            return "Staging"
        case .training:
            return "Training"
        case .prod:
            return "Prod"
        }
    }

    var configuration: EnvironmentConfiguration {
        switch self {
        case .staging:
            return EnvironmentConfiguration(
                secrets: AppSecrets.current.staging
            )
        case .training:
            return EnvironmentConfiguration(
                secrets: AppSecrets.current.training
            )
        case .prod:
            return EnvironmentConfiguration(
                secrets: AppSecrets.current.prod
            )
        }
    }
}

struct EnvironmentConfiguration {
    let hubURL: URL
    let azureClientID: String
    let azureTenantID: String
    let azureClientSecret: String

    init(secrets: EnvironmentSecrets) {
        self.hubURL = secrets.hubURL
        self.azureClientID = secrets.azureClientID
        self.azureTenantID = secrets.azureTenantID
        self.azureClientSecret = secrets.azureClientSecret
    }

    var entraAuthorizeURL: URL {
        URL(string: "https://login.microsoftonline.com/\(azureTenantID)/oauth2/v2.0/authorize")!
    }

    var entraTokenURL: URL {
        URL(string: "https://login.microsoftonline.com/\(azureTenantID)/oauth2/v2.0/token")!
    }
}
