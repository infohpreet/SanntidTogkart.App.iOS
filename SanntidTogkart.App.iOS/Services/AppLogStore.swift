import Foundation
import Observation

struct AppLogEntry: Codable, Identifiable, Sendable {
    let id: UUID
    let timestamp: Date
    let level: AppLogLevel
    let category: String
    let message: String
    let details: String?

    init(
        id: UUID = UUID(),
        timestamp: Date = AppTime.now,
        level: AppLogLevel,
        category: String,
        message: String,
        details: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.level = level
        self.category = category
        self.message = message
        self.details = details
    }
}

enum AppLogLevel: String, Codable, Sendable {
    case error
}

@MainActor
@Observable
final class AppLogStore {
    static let shared = AppLogStore()

    private enum StorageKeys {
        static let entries = "app.logs.entries"
        static let maxEntryCount = 200
        static let maxMessageLength = 240
        static let maxDetailsLength = 4000
    }

    private(set) var entries: [AppLogEntry]

    private let userDefaults: UserDefaults

    var entryCount: Int {
        entries.count
    }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.entries = Self.loadEntries(from: userDefaults)
    }

    func logError(category: String, message: String, details: String? = nil) {
        append(
            level: .error,
            category: category,
            message: message,
            details: details
        )
    }

    func clear() {
        entries = []
        persistEntries()
    }

    private func append(level: AppLogLevel, category: String, message: String, details: String?) {
        let trimmedMessage = Self.trimmed(message, maxLength: StorageKeys.maxMessageLength) ?? "Ukjent feil"
        let trimmedDetails = Self.trimmed(details, maxLength: StorageKeys.maxDetailsLength)

        entries.insert(
            AppLogEntry(
                level: level,
                category: category,
                message: trimmedMessage,
                details: trimmedDetails
            ),
            at: 0
        )

        if entries.count > StorageKeys.maxEntryCount {
            entries.removeLast(entries.count - StorageKeys.maxEntryCount)
        }

        persistEntries()
    }

    private func persistEntries() {
        guard let data = try? JSONEncoder().encode(entries) else {
            return
        }

        userDefaults.set(data, forKey: StorageKeys.entries)
    }

    private static func loadEntries(from userDefaults: UserDefaults) -> [AppLogEntry] {
        guard let data = userDefaults.data(forKey: StorageKeys.entries) else {
            return []
        }

        return (try? JSONDecoder().decode([AppLogEntry].self, from: data)) ?? []
    }

    private static func trimmed(_ value: String?, maxLength: Int) -> String? {
        guard let value else {
            return nil
        }

        let normalizedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedValue.isEmpty else {
            return nil
        }

        guard normalizedValue.count > maxLength else {
            return normalizedValue
        }

        let endIndex = normalizedValue.index(normalizedValue.startIndex, offsetBy: maxLength)
        return String(normalizedValue[..<endIndex]) + "…"
    }
}
