import SwiftUI

struct FavoriteTabView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    welcomeSection
                }
                .padding(20)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Favoritter")
        }
    }

    private var welcomeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sanntid Togkart")
                .font(.system(size: 30, weight: .bold, design: .rounded))

            Text("Få rask tilgang til live togdata og favorittfunksjoner når de blir tilgjengelige.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
