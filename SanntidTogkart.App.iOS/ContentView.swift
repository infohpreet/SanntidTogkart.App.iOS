//
//  ContentView.swift
//  SanntidTogkart.App.iOS
//
//  Created by Harpreet Singh on 08/03/2026.
//

import SwiftUI

struct ContentView: View {
    @State private var authSession = AuthSession()
    @AppStorage("appAppearanceMode") private var appAppearanceModeRawValue = AppAppearanceMode.system.rawValue
    @AppStorage("hasSeenAppIntroduction") private var hasSeenAppIntroduction = false
    @AppStorage("showAppIntroductionOnNextLaunch") private var showAppIntroductionOnNextLaunch = false
    @State private var isShowingIntroduction = false

    var body: some View {
        Group {
            if let currentUser = activeUser {
                DashboardView(user: currentUser, authSession: authSession, onLogout: {
                    self.authSession.signOut()
                })
            } else {
                LoginView(authSession: authSession, onLogin: { _ in
                })
            }
        }
        .task {
            await authSession.restoreSessionIfNeeded()
        }
        .task(id: activeUser?.username) {
            guard activeUser != nil, shouldPresentIntroduction else {
                isShowingIntroduction = false
                return
            }

            isShowingIntroduction = true
        }
        .preferredColorScheme(appAppearanceMode.colorScheme)
        .fullScreenCover(isPresented: $isShowingIntroduction) {
            AppIntroductionView(onFinish: {
                hasSeenAppIntroduction = true
                showAppIntroductionOnNextLaunch = false
                isShowingIntroduction = false
            })
        }
        .alert("Aktivere Face ID?", isPresented: biometricPromptIsPresented) {
            Button("Ikke nå", role: .cancel) {
                authSession.markBiometricPromptHandled()
            }
            Button("Aktiver") {
                authSession.markBiometricPromptHandled()
                Task {
                    _ = await authSession.setBiometricEnabled(true)
                }
            }
        } message: {
            Text("Bruk Face ID for å holde deg innlogget mellom appstarter.")
        }
    }

    private var activeUser: EntraIDUser? {
        #if targetEnvironment(simulator)
        authSession.currentUser ?? EntraIDUser(
            displayName: "Simulator User",
            username: "simulator@banenor.no",
            accessToken: "simulator-access-token",
            profileImageData: nil
        )
        #else
        authSession.currentUser
        #endif
    }

    private var appAppearanceMode: AppAppearanceMode {
        AppAppearanceMode(rawValue: appAppearanceModeRawValue) ?? .system
    }

    private var shouldPresentIntroduction: Bool {
        !hasSeenAppIntroduction || showAppIntroductionOnNextLaunch
    }

    private var biometricPromptIsPresented: Binding<Bool> {
        Binding(
            get: {
                activeUser != nil &&
                !isShowingIntroduction &&
                authSession.shouldPromptForBiometricsAfterLogin
            },
            set: { isPresented in
                if !isPresented {
                    authSession.markBiometricPromptHandled()
                }
            }
        )
    }
}

#Preview {
    ContentView()
}
