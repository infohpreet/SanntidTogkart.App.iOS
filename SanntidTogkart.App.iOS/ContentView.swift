//
//  ContentView.swift
//  SanntidTogkart.App.iOS
//
//  Created by Harpreet Singh on 08/03/2026.
//

import SwiftUI

struct ContentView: View {
    @State private var authSession = AuthSession()

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
}

#Preview {
    ContentView()
}
