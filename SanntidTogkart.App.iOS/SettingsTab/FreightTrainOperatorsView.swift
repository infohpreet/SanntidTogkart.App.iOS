import SwiftUI

struct FreightTrainOperatorsView: View {
    private let operators = CommonService.freightTrainOperators

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                summaryCard
                operatorsCard
            }
            .padding(20)
            .appReadableContentWidth()
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Godstogoperatører")
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Oversikt", systemImage: "info.circle")
                .font(.headline)

            Text("Denne listen brukes for å identifisere godstogoperatører i appen.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Antall: \(operators.count)")
                .font(.subheadline.weight(.medium))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 8))
    }

    private var operatorsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(operators.enumerated()), id: \.element) { index, operatorCode in
                HStack(spacing: 12) {
                    Text(operatorCode)
                        .font(.subheadline.monospaced().weight(.semibold))
                        .foregroundStyle(.primary)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                if index < operators.count - 1 {
                    Rectangle()
                        .fill(AppTheme.border)
                        .frame(height: 1)
                        .padding(.leading, 16)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.border, lineWidth: 1)
        }
    }
}
