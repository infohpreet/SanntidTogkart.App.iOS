import Foundation

enum AuthConfig {
    static var currentEnvironment: AppEnvironment {
        get {
            .training
        }
        set {
            UserDefaults.standard.set(AppEnvironment.training.rawValue, forKey: StorageKeys.environment)
        }
    }

    static var signalRCurrent: EnvironmentConfiguration {
        currentEnvironment.signalRConfiguration
    }

    static var loginCurrent: LoginConfiguration {
        LoginConfiguration(secrets: AuthLoginSecrets.current.authLogin)
    }

    static var hubURL: URL { signalRCurrent.hubURL }
    static var azureClientID: String { signalRCurrent.azureClientID }
    static var azureTenantID: String { signalRCurrent.azureTenantID }
    static var azureClientSecret: String { signalRCurrent.azureClientSecret }

    static var ssoAzureClientID: String { loginCurrent.azureClientID }
    static var ssoAzureTenantID: String { loginCurrent.azureTenantID }
    static var ssoAzureClientSecret: String { loginCurrent.azureClientSecret }
    static var ssoEntraAuthorizeURL: URL { loginCurrent.entraAuthorizeURL }
    static var ssoEntraTokenURL: URL { loginCurrent.entraTokenURL }

    static var signalREntraTokenURL: URL { signalRCurrent.entraTokenURL }
    static var signalRClientCredentialScope: String { "api://\(azureClientID)/.default" }

    static let ssoCallbackScheme = "sanntidtogkart"
    static let ssoRedirectURI = "\(ssoCallbackScheme)://auth"
    static var ssoScopes: [String] {
        [
            "openid",
            "profile",
            "email",
            "offline_access",
            "api://\(ssoAzureClientID)/access_as_user"
        ]
    }

    private enum StorageKeys {
        static let environment = "app.environment"
    }
}

enum AppEnvironment: String, CaseIterable, Identifiable {
    case prod
    case training
    case staging

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

    var signalRConfiguration: EnvironmentConfiguration {
        switch self {
        case .staging:
            return EnvironmentConfiguration(
                secrets: AuthSignalRSecrets.current.staging
            )
        case .training:
            return EnvironmentConfiguration(
                secrets: AuthSignalRSecrets.current.training
            )
        case .prod:
            return EnvironmentConfiguration(
                secrets: AuthSignalRSecrets.current.prod
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

struct LoginConfiguration {
    let azureClientID: String
    let azureTenantID: String
    let azureClientSecret: String

    init(secrets: EnvironmentSecrets) {
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
