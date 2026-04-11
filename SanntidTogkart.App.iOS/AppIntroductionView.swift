import SwiftUI

struct AppIntroductionView: View {
    let onFinish: () -> Void

    @State private var selectedPage = 0

    private let pages: [IntroductionPage] = [
        IntroductionPage(
            title: "Velkommen til Sanntid Togkart",
            subtitle: "Se tog i bevegelse, finn stasjoner raskt og hold oversikt over ruter i sanntid.",
            systemImage: "sparkles.rectangle.stack",
            accentColor: Color.accentColor
        ),
        IntroductionPage(
            title: "Live kart og togposisjoner",
            subtitle: "Folg tog direkte i kartet, se status og fa oppdatert avstand videre mot destinasjonen.",
            systemImage: "map.circle",
            accentColor: Color.orange
        ),
        IntroductionPage(
            title: "Favoritter og raske valg",
            subtitle: "Lag favorittstasjoner, apne meldinger med ett trykk og hopp rett til togdetaljer.",
            systemImage: "star.circle",
            accentColor: Color.green
        ),
        IntroductionPage(
            title: "Aktiver Face ID",
            subtitle: "Etter første innlogging kan du aktivere Face ID for å holde deg innlogget mellom appstarter.",
            systemImage: "faceid",
            accentColor: Color.blue
        ),
        IntroductionPage(
            title: "Velg riktig miljø",
            subtitle: "Du kan bytte mellom Prod, Training og Staging både fra login-siden og i Innstillinger.",
            systemImage: "network",
            accentColor: Color.pink
        )
    ]

    var body: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()

            backgroundDecor

            VStack(spacing: 0) {
                header

                TabView(selection: $selectedPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        IntroductionPageView(page: page)
                            .tag(index)
                            .padding(.horizontal, 24)
                            .padding(.top, 12)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                footer
            }
        }
    }

    private var header: some View {
        HStack {
            Text("Kom i gang")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)

            Spacer()

            Button("Hopp over") {
                onFinish()
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
    }

    private var footer: some View {
        VStack(spacing: 18) {
            HStack(spacing: 8) {
                ForEach(pages.indices, id: \.self) { index in
                    Capsule()
                        .fill(index == selectedPage ? Color.accentColor : AppTheme.border)
                        .frame(width: index == selectedPage ? 24 : 8, height: 8)
                        .animation(.spring(response: 0.25, dampingFraction: 0.88), value: selectedPage)
                }
            }

            Button(action: advance) {
                HStack(spacing: 10) {
                    Text(selectedPage == pages.count - 1 ? "Start appen" : "Neste")
                        .font(.headline)

                    Image(systemName: selectedPage == pages.count - 1 ? "checkmark.circle.fill" : "arrow.right")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .foregroundStyle(Color.white)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.accentColor)
                )
            }

            if selectedPage < pages.count - 1 {
                Button("Gaa til siste") {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
                        selectedPage = pages.count - 1
                    }
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 28)
    }

    private var backgroundDecor: some View {
        GeometryReader { geometry in
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 240, height: 240)
                    .blur(radius: 18)
                    .offset(x: geometry.size.width * 0.28, y: -geometry.size.height * 0.22)

                Circle()
                    .fill(Color.orange.opacity(0.10))
                    .frame(width: 200, height: 200)
                    .blur(radius: 20)
                    .offset(x: -geometry.size.width * 0.22, y: geometry.size.height * 0.22)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func advance() {
        if selectedPage == pages.count - 1 {
            onFinish()
            return
        }

        withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
            selectedPage += 1
        }
    }
}

private struct IntroductionPageView: View {
    let page: IntroductionPage

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 20)

            ZStack {
                RoundedRectangle(cornerRadius: 36, style: .continuous)
                    .fill(page.accentColor.opacity(0.14))
                    .frame(width: 212, height: 212)
                    .overlay(
                        RoundedRectangle(cornerRadius: 36, style: .continuous)
                            .stroke(page.accentColor.opacity(0.20), lineWidth: 1)
                    )

                Image(systemName: page.systemImage)
                    .font(.system(size: 78, weight: .medium))
                    .foregroundStyle(page.accentColor)
            }

            VStack(spacing: 14) {
                Text(page.title)
                    .font(.system(size: 31, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)

                Text(page.subtitle)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 420)
            }

            featureCard

            Spacer()
        }
    }

    private var featureCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(page.accentColor)
                Text("Klar for første tur")
                    .font(.headline)
            }

            Text(page.supportingText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AppTheme.surface.opacity(0.94))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }
}

private struct IntroductionPage {
    let title: String
    let subtitle: String
    let systemImage: String
    let accentColor: Color

    var supportingText: String {
        subtitle
    }
}
