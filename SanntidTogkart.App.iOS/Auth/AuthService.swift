import AuthenticationServices
import CryptoKit
import Foundation
import UIKit

struct EntraIDUser: Codable {
    let displayName: String
    let username: String
    let accessToken: String
    let profileImageData: Data?
}

@MainActor
final class AuthService: NSObject {
    private var webAuthenticationSession: ASWebAuthenticationSession?

    func signIn() async throws -> EntraIDUser {
        let state = Self.makeRandomString()
        let nonce = Self.makeRandomString()
        let codeVerifier = Self.makeRandomString(length: 64)
        let codeChallenge = Self.makeCodeChallenge(from: codeVerifier)

        let callbackURL = try await authenticate(
            using: try makeAuthorizationURL(
                state: state,
                nonce: nonce,
                codeChallenge: codeChallenge
            )
        )
        let authorizationCode = try extractAuthorizationCode(from: callbackURL, expectedState: state)
        let tokenResponse = try await exchangeCodeForTokens(
            authorizationCode: authorizationCode,
            codeVerifier: codeVerifier
        )
        let claims = try decodeIDTokenClaims(tokenResponse.idToken)
        let displayName = claims.displayName ?? claims.preferredUsername ?? "Bane NOR"
        let username = claims.preferredUsername ?? claims.email ?? displayName
        let profileImageData = try? await fetchProfilePhoto(accessToken: tokenResponse.accessToken)

        return EntraIDUser(
            displayName: displayName,
            username: username,
            accessToken: tokenResponse.accessToken,
            profileImageData: profileImageData
        )
    }

    private func makeAuthorizationURL(
        state: String,
        nonce: String,
        codeChallenge: String
    ) throws -> URL {
        let config = AuthConfig.current

        guard var components = URLComponents(url: config.entraAuthorizeURL, resolvingAgainstBaseURL: false) else {
            throw EntraIDAuthError.invalidAuthorizationURL
        }

        components.queryItems = [
            URLQueryItem(name: "client_id", value: config.azureClientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: AuthConfig.ssoRedirectURI),
            URLQueryItem(name: "response_mode", value: "query"),
            URLQueryItem(name: "scope", value: AuthConfig.ssoScopes.joined(separator: " ")),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "nonce", value: nonce),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "prompt", value: "select_account")
        ]

        guard let url = components.url else {
            throw EntraIDAuthError.invalidAuthorizationURL
        }

        return url
    }

    private func authenticate(using url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: AuthConfig.ssoCallbackScheme
            ) { [weak self] callbackURL, error in
                self?.webAuthenticationSession = nil

                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let callbackURL else {
                    continuation.resume(throwing: EntraIDAuthError.missingCallbackURL)
                    return
                }

                continuation.resume(returning: callbackURL)
            }

            session.prefersEphemeralWebBrowserSession = true
            session.presentationContextProvider = self
            self.webAuthenticationSession = session

            guard session.start() else {
                self.webAuthenticationSession = nil
                continuation.resume(throwing: EntraIDAuthError.failedToStartSession)
                return
            }
        }
    }

    private func extractAuthorizationCode(from callbackURL: URL, expectedState: String) throws -> String {
        guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false) else {
            throw EntraIDAuthError.invalidCallbackURL
        }

        if let error = components.queryItems?.first(where: { $0.name == "error" })?.value {
            let errorDescription = components.queryItems?.first(where: { $0.name == "error_description" })?.value
            throw EntraIDAuthError.providerError(error, errorDescription)
        }

        let state = components.queryItems?.first(where: { $0.name == "state" })?.value
        guard state == expectedState else {
            throw EntraIDAuthError.invalidState
        }

        guard let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            throw EntraIDAuthError.missingAuthorizationCode
        }

        return code
    }

    private func exchangeCodeForTokens(
        authorizationCode: String,
        codeVerifier: String
    ) async throws -> EntraTokenResponse {
        let config = AuthConfig.current
        var request = URLRequest(url: config.entraTokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formEncodedBody([
            "client_id": config.azureClientID,
            "grant_type": "authorization_code",
            "code": authorizationCode,
            "redirect_uri": AuthConfig.ssoRedirectURI,
            "code_verifier": codeVerifier,
            "scope": AuthConfig.ssoScopes.joined(separator: " ")
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTPResponse(response, data: data)

        return try JSONDecoder().decode(EntraTokenResponse.self, from: data)
    }

    private func decodeIDTokenClaims(_ idToken: String) throws -> EntraIDTokenClaims {
        let parts = idToken.split(separator: ".")
        guard parts.count >= 2 else {
            throw EntraIDAuthError.invalidIDToken
        }

        let payload = String(parts[1])
        let normalizedPayload = payload
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padding = String(repeating: "=", count: (4 - normalizedPayload.count % 4) % 4)

        guard let data = Data(base64Encoded: normalizedPayload + padding) else {
            throw EntraIDAuthError.invalidIDToken
        }

        return try JSONDecoder().decode(EntraIDTokenClaims.self, from: data)
    }

    private func fetchProfilePhoto(accessToken: String) async throws -> Data? {
        var request = URLRequest(url: URL(string: "https://graph.microsoft.com/v1.0/me/photo/$value")!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw EntraIDAuthError.invalidHTTPResponse
        }

        if httpResponse.statusCode == 404 {
            return nil
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Ukjent serverrespons"
            throw EntraIDAuthError.httpError(statusCode: httpResponse.statusCode, message: message)
        }

        return data
    }

    private func validateHTTPResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw EntraIDAuthError.invalidHTTPResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Ukjent serverrespons"
            throw EntraIDAuthError.httpError(statusCode: httpResponse.statusCode, message: message)
        }
    }

    private func formEncodedBody(_ values: [String: String]) -> Data? {
        var components = URLComponents()
        components.queryItems = values.map { key, value in
            URLQueryItem(name: key, value: value)
        }
        return components.percentEncodedQuery?.data(using: .utf8)
    }

    private static func makeRandomString(length: Int = 32) -> String {
        let characters = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        return String((0..<length).compactMap { _ in characters.randomElement() })
    }

    private static func makeCodeChallenge(from codeVerifier: String) -> String {
        let hash = SHA256.hash(data: Data(codeVerifier.utf8))
        return Data(hash)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

extension AuthService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }

        if let window = windows.first(where: \.isKeyWindow) {
            return window
        }

        if let window = windows.first {
            return window
        }

        if let windowScene = UIApplication.shared.connectedScenes.first(where: { $0 is UIWindowScene }) as? UIWindowScene {
            return UIWindow(windowScene: windowScene)
        }

        fatalError("No UIWindowScene available for authentication presentation.")
    }
}

private struct EntraTokenResponse: Decodable {
    let accessToken: String
    let idToken: String

    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case idToken = "id_token"
    }
}

private struct EntraIDTokenClaims: Decodable {
    let displayName: String?
    let preferredUsername: String?
    let email: String?

    private enum CodingKeys: String, CodingKey {
        case displayName = "name"
        case preferredUsername = "preferred_username"
        case email
    }
}

private enum EntraIDAuthError: LocalizedError {
    case failedToStartSession
    case httpError(statusCode: Int, message: String)
    case invalidAuthorizationURL
    case invalidCallbackURL
    case invalidHTTPResponse
    case invalidIDToken
    case invalidState
    case missingAuthorizationCode
    case missingCallbackURL
    case providerError(String, String?)

    var errorDescription: String? {
        switch self {
        case .failedToStartSession:
            return "Kunne ikke starte Bane NOR SSO."
        case .httpError(let statusCode, let message):
            return "HTTP \(statusCode): \(message)"
        case .invalidAuthorizationURL:
            return "SSO-konfigurasjonen er ugyldig."
        case .invalidCallbackURL:
            return "Mottok ugyldig callback fra Entra ID."
        case .invalidHTTPResponse:
            return "Ugyldig respons fra Entra ID."
        case .invalidIDToken:
            return "Kunne ikke lese ID-token fra Entra ID."
        case .invalidState:
            return "SSO state-verifisering feilet."
        case .missingAuthorizationCode:
            return "Entra ID returnerte ikke authorization code."
        case .missingCallbackURL:
            return "Entra ID returnerte ikke callback-URL."
        case .providerError(let error, let description):
            return description ?? error
        }
    }
}
