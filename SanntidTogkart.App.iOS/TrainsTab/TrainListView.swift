import SwiftUI

struct TrainListView: View {
    let station: TraseStation

    @State private var favoritesStore = TrainStationFavoritesStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(stationMetadataLine)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)
        }
        .padding(16)
        .appReadableContentWidth()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle(station.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    favoritesStore.toggle(station)
                } label: {
                    Image(systemName: favoritesStore.isFavorite(station) ? "star.fill" : "star")
                        .foregroundStyle(favoritesStore.isFavorite(station) ? Color.accentColor : .secondary)
                }
                .accessibilityLabel(favoritesStore.isFavorite(station) ? "Fjern favoritt" : "Legg til favoritt")
            }
        }
    }

    private var stationMetadataLine: String {
        [station.shortName, station.plcCode?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "", station.countryCode]
            .filter { !$0.isEmpty }
            .joined(separator: " • ")
    }
}
