import Foundation

/// Which clock decides what "today" is.
public enum DateBasis: String, Codable, CaseIterable, Sendable {
    /// Follow Nepal Standard Time (UTC+05:45). The Nepali date flips at midnight in Nepal,
    /// no matter where you are. This is the default and the whole point of this app.
    case nepal
    /// Follow this Mac's time zone.
    case local

    public var timeZone: TimeZone {
        switch self {
        case .nepal: return NepalTime.timeZone
        case .local: return .current
        }
    }
}

public enum NepalTime {
    public static let timeZone: TimeZone = TimeZone(identifier: "Asia/Kathmandu") ?? TimeZone(secondsFromGMT: 20_700)!

    /// Kathmandu, used for sunrise/sunset and tithi calculations.
    public static let latitude = 27.7172
    public static let longitude = 85.3240

    public static func todayJDN(_ basis: DateBasis = .nepal, now: Date = Date()) -> Int {
        JDN.of(now, in: basis.timeZone)
    }

    public static func today(_ basis: DateBasis = .nepal, now: Date = Date()) -> BSDate? {
        BSDate(jdn: todayJDN(basis, now: now))
    }

    /// The next instant at which the date changes for the given basis.
    public static func nextDayChange(after now: Date = Date(), basis: DateBasis = .nepal) -> Date {
        let tz = basis.timeZone
        return JDN.startOfDay(JDN.of(now, in: tz) + 1, in: tz)
    }

    /// How many hours/minutes Nepal is ahead of the given zone at this instant (e.g. "+10:45").
    public static func offsetDescription(from zone: TimeZone = .current, at date: Date = Date()) -> String {
        let diff = timeZone.secondsFromGMT(for: date) - zone.secondsFromGMT(for: date)
        let sign = diff >= 0 ? "+" : "−"
        let a = abs(diff)
        return String(format: "%@%d:%02d", sign, a / 3600, (a % 3600) / 60)
    }

    public static func offsetSeconds(from zone: TimeZone = .current, at date: Date = Date()) -> Int {
        timeZone.secondsFromGMT(for: date) - zone.secondsFromGMT(for: date)
    }
}
