import SwiftUI

struct AppLogView: View {
    @State private var logStore = AppLogStore.shared

    var body: some View {
        Group {
            if logStore.entries.isEmpty {
                ContentUnavailableView(
                    "Ingen logger",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Feil og dekodingslogger vil vises her når appen registrerer dem.")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(logStore.entries) { entry in
                            logCard(for: entry)
                        }
                    }
                    .padding(16)
                    .appReadableContentWidth()
                }
                .scrollIndicators(.hidden)
            }
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Logger")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Tøm") {
                    logStore.clear()
                }
                .disabled(logStore.entries.isEmpty)
            }
        }
    }

    private func logCard(for entry: AppLogEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(entry.category)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer(minLength: 8)

                Text(timestampText(for: entry.timestamp))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Text(entry.message)
                .font(.subheadline)
                .foregroundStyle(.primary)

            if let details = entry.details {
                Text(details)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func timestampText(for timestamp: Date) -> String {
        "\(AppTime.localDateString(from: timestamp)) \(AppTime.localTimeString(from: timestamp, includesSeconds: true))"
    }
}