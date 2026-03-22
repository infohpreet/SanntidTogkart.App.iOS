import Foundation
import LocalAuthentication
import Observation

@MainActor
@Observable
final class AuthSession {
    var currentUser: EntraIDUser?
    var errorMessage: String?
    var isAuthenticating = false
    var isAuthenticatingWithBiometrics = false
    var isPreparingDashboard = false
    var isBiometricEnabled: Bool
    var isRestoringSession = true

    private let authService: AuthService
    private let userDefaults: UserDefaults
    private let persistedUser: EntraIDUser?

    private enum StorageKeys {
        static let biometricsEnabled = "auth.biometricsEnabled"
        static let currentUser = "auth.currentUser"
    }

    init() {
        self.authService = AuthService()
        self.userDefaults = Foundation.UserDefaults.standard
        self.isBiometricEnabled = Foundation.UserDefaults.standard.bool(forKey: StorageKeys.biometricsEnabled)
        self.persistedUser = Self.loadPersistedUser(from: Foundation.UserDefaults.standard)
        self.currentUser = nil
    }

    init(authService: AuthService) {
        self.authService = authService
        self.userDefaults = Foundation.UserDefaults.standard
        self.isBiometricEnabled = Foundation.UserDefaults.standard.bool(forKey: StorageKeys.biometricsEnabled)
        self.persistedUser = Self.loadPersistedUser(from: Foundation.UserDefaults.standard)
        self.currentUser = nil
    }

    func restoreSessionIfNeeded() async {
        guard isRestoringSession else {
            return
        }

        defer { isRestoringSession = false }

        guard isBiometricEnabled, let persistedUser else {
            return
        }

        do {
            _ = try await authenticateWithBiometrics(reason: "Bruk Face ID for å åpne Sanntid Togkart.")
            await prepareDashboardTransition()
            currentUser = persistedUser
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signInWithSSO() async -> EntraIDUser? {
        guard !isAuthenticating else {
            return nil
        }

        isAuthenticating = true
        errorMessage = nil
        defer { isAuthenticating = false }

        do {
            let user = try await authService.signIn()
            currentUser = user
            if isBiometricEnabled {
                persist(user: user)
            }
            return user
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func clearError() {
        errorMessage = nil
    }

    func signOut() {
        currentUser = nil
        errorMessage = nil
        userDefaults.removeObject(forKey: StorageKeys.currentUser)
    }

    func setBiometricEnabled(_ isEnabled: Bool) async -> Bool {
        if isEnabled {
            do {
                _ = try await authenticateWithBiometrics(reason: "Aktiver Face ID for å holde deg innlogget i Sanntid Togkart.")
                isBiometricEnabled = true
                userDefaults.set(true, forKey: StorageKeys.biometricsEnabled)

                if let currentUser {
                    persist(user: currentUser)
                }

                return true
            } catch {
                errorMessage = error.localizedDescription
                return false
            }
        } else {
            isBiometricEnabled = false
            userDefaults.set(false, forKey: StorageKeys.biometricsEnabled)
            userDefaults.removeObject(forKey: StorageKeys.currentUser)
            return true
        }
    }

    private func persist(user: EntraIDUser) {
        guard let data = try? JSONEncoder().encode(user) else {
            return
        }

        userDefaults.set(data, forKey: StorageKeys.currentUser)
    }

    private static func loadPersistedUser(from userDefaults: UserDefaults) -> EntraIDUser? {
        guard let data = userDefaults.data(forKey: StorageKeys.currentUser) else {
            return nil
        }

        return try? JSONDecoder().decode(EntraIDUser.self, from: data)
    }

    private func authenticateWithBiometrics(reason: String) async throws -> Bool {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            throw error ?? AuthSessionError.biometricsUnavailable
        }

        isAuthenticatingWithBiometrics = true
        defer { isAuthenticatingWithBiometrics = false }

        return try await withCheckedThrowingContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume(returning: success)
            }
        }
    }

    private func prepareDashboardTransition() async {
        isPreparingDashboard = true
        defer { isPreparingDashboard = false }

        try? await Task.sleep(for: .milliseconds(450))
    }
}

private enum AuthSessionError: LocalizedError {
    case biometricsUnavailable

    var errorDescription: String? {
        switch self {
        case .biometricsUnavailable:
            return "Face ID er ikke tilgjengelig på denne enheten."
        }
    }
}
