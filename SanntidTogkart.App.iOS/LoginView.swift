import SwiftUI
import Observation

struct LoginView: View {
    @Bindable var authSession: AuthSession
    var onLogin: (EntraIDUser) -> Void
    @State private var isFaceIDAnimating = false
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color.accentColor.opacity(0.08),
                    Color(.secondarySystemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 28) {
                VStack(spacing: 14) {
                    Image("BaneNorLogo")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 180, height: 30)
                        .foregroundStyle(.primary)
                }

                if authSession.isPreparingDashboard {
                    DashboardTransitionCard()
                        .frame(maxWidth: 420)
                } else if authSession.isRestoringSession || authSession.isAuthenticatingWithBiometrics {
                    FaceIDWaitingCard(isAnimating: isFaceIDAnimating)
                        .frame(maxWidth: 420)
                } else {
                    VStack(spacing: 12) {
                        Button(action: {
                            authSession.clearError()
                            
                            Task {
                                if let user = await authSession.signInWithSSO() {
                                    onLogin(user)
                                }
                            }
                        }) {
                            HStack(spacing: 10) {
                                MicrosoftLogo()
                                Text(authSession.isAuthenticating ? "Signing In..." : "Sign In")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .foregroundStyle(Color.accentColor)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.accentColor.opacity(0.35), lineWidth: 1)
                            )
                        }
                        .disabled(authSession.isAuthenticating)

                        if let errorMessage = authSession.errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(maxWidth: 420)
                }
            }
            .padding(24)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.15).repeatForever(autoreverses: true)) {
                isFaceIDAnimating = true
            }
        }
    }
}

private struct FaceIDWaitingCard: View {
    let isAnimating: Bool

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.08))
                    .frame(width: 104, height: 104)
                    .scaleEffect(isAnimating ? 1.08 : 0.92)

                Circle()
                    .stroke(Color.accentColor.opacity(0.22), lineWidth: 1.5)
                    .frame(width: 86, height: 86)
                    .scaleEffect(isAnimating ? 1.12 : 0.96)

                Image(systemName: "faceid")
                    .font(.system(size: 38, weight: .medium))
                    .foregroundStyle(Color.accentColor)
                    .scaleEffect(isAnimating ? 1.04 : 0.96)
            }

            VStack(spacing: 6) {
                Text("Venter på Face ID")
                    .font(.headline)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
    }
}

private struct DashboardTransitionCard: View {
    var body: some View {
        VStack(spacing: 14) {
            ProgressView()
                .controlSize(.regular)
                .tint(.accentColor)

            VStack(spacing: 6) {
                Text("Vennligst vent...")
                    .font(.headline)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }
}

private struct MicrosoftLogo: View {
    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 2) {
                Color(red: 0.95, green: 0.30, blue: 0.23)
                Color(red: 0.50, green: 0.73, blue: 0.24)
            }
            HStack(spacing: 2) {
                Color(red: 0.00, green: 0.64, blue: 0.91)
                Color(red: 0.98, green: 0.74, blue: 0.10)
            }
        }
        .frame(width: 18, height: 18)
    }
}
