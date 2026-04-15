import Foundation

enum AppTime {
    static var now: Date {
        Date()
    }

    static func localDateString(from date: Date = now) -> String {
        localDayFormatter.string(from: date)
    }

    static func utcDateString(from date: Date = now) -> String {
        utcDayFormatter.string(from: date)
    }

    static func localTimeString(from date: Date, includesSeconds: Bool = false) -> String {
        if includesSeconds {
            return localTimeWithSecondsFormatter.string(from: date)
        }

        return localTimeFormatter.string(from: date)
    }

    private static let localDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.autoupdatingCurrent
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let utcDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let localTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.autoupdatingCurrent
        formatter.locale = Locale.autoupdatingCurrent
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let localTimeWithSecondsFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.autoupdatingCurrent
        formatter.locale = Locale.autoupdatingCurrent
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}
