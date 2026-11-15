import Foundation

/// Julian Day Number helpers. A JDN identifies a civil day independent of time zone,
/// which makes it a convenient common currency between the AD and BS calendars.
public enum JDN {
    /// Unix epoch (1970-01-01) as a JDN.
    public static let unixEpoch = 2_440_588

    public static func from(year: Int, month: Int, day: Int) -> Int {
        let a = (14 - month) / 12
        let y = year + 4800 - a
        let m = month + 12 * a - 3
        return day + (153 * m + 2) / 5 + 365 * y + y / 4 - y / 100 + y / 400 - 32045
    }

    public static func toGregorian(_ jdn: Int) -> (year: Int, month: Int, day: Int) {
        let a = jdn + 32044
        let b = (4 * a + 3) / 146_097
        let c = a - 146_097 * b / 4
        let d = (4 * c + 3) / 1461
        let e = c - 1461 * d / 4
        let m = (5 * e + 2) / 153
        let day = e - (153 * m + 2) / 5 + 1
        let month = m + 3 - 12 * (m / 10)
        let year = 100 * b + d - 4800 + m / 10
        return (year, month, day)
    }

    /// 0 = Sunday ... 6 = Saturday
    public static func weekday(_ jdn: Int) -> Int {
        ((jdn + 1) % 7 + 7) % 7
    }

    /// The civil day an instant falls on in the given time zone.
    public static func of(_ date: Date, in timeZone: TimeZone) -> Int {
        let seconds = date.timeIntervalSince1970 + Double(timeZone.secondsFromGMT(for: date))
        return unixEpoch + Int((seconds / 86_400).rounded(.down))
    }

    /// The instant at which the given civil day starts in a time zone.
    public static func startOfDay(_ jdn: Int, in timeZone: TimeZone) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let g = toGregorian(jdn)
        let comps = DateComponents(year: g.year, month: g.month, day: g.day)
        return calendar.date(from: comps) ?? Date(timeIntervalSince1970: Double(jdn - unixEpoch) * 86_400)
    }
}

public struct ADDate: Hashable, Codable, Comparable, Sendable {
    public var year: Int
    public var month: Int
    public var day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    public init(jdn: Int) {
        let g = JDN.toGregorian(jdn)
        self.init(year: g.year, month: g.month, day: g.day)
    }

    public var jdn: Int { JDN.from(year: year, month: month, day: day) }
    public var weekday: Int { JDN.weekday(jdn) }

    public var isValid: Bool {
        guard (1...12).contains(month), day >= 1 else { return false }
        return day <= ADDate.daysInMonth(year: year, month: month)
    }

    public static func daysInMonth(year: Int, month: Int) -> Int {
        let next = month == 12 ? JDN.from(year: year + 1, month: 1, day: 1) : JDN.from(year: year, month: month + 1, day: 1)
        return next - JDN.from(year: year, month: month, day: 1)
    }

    public static func < (lhs: ADDate, rhs: ADDate) -> Bool { lhs.jdn < rhs.jdn }
}

public struct BSDate: Hashable, Codable, Comparable, Sendable, CustomStringConvertible {
    public var year: Int
    /// 1 = Baisakh ... 12 = Chaitra
    public var month: Int
    public var day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    public init?(jdn: Int) {
        guard let d = BSCalendar.fromJDN(jdn) else { return nil }
        self = d
    }

    public var jdn: Int? { BSCalendar.toJDN(self) }
    public var adDate: ADDate? { jdn.map(ADDate.init(jdn:)) }
    public var weekday: Int? { jdn.map(JDN.weekday) }
    public var isValid: Bool { BSCalendar.toJDN(self) != nil }

    public var description: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    public static func < (lhs: BSDate, rhs: BSDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}

public enum BSCalendar {
    public static let firstYear = 1975
    public static var lastYear: Int { firstYear + monthLengthTable.count - 1 }
    /// 1975-01-01 BS
    public static let epochJDN = JDN.from(year: 1918, month: 4, day: 13)

    private static let yearStarts: [Int] = {
        var starts: [Int] = []
        var jdn = epochJDN
        for row in monthLengthTable {
            starts.append(jdn)
            jdn += row.reduce(0) { $0 + Int($1) }
        }
        starts.append(jdn)
        return starts
    }()

    public static var firstJDN: Int { yearStarts.first! }
    /// Exclusive upper bound.
    public static var endJDN: Int { yearStarts.last! }

    public static func contains(year: Int) -> Bool {
        year >= firstYear && year <= lastYear
    }

    public static func daysInMonth(year: Int, month: Int) -> Int? {
        guard contains(year: year), (1...12).contains(month) else { return nil }
        return Int(monthLengthTable[year - firstYear][month - 1])
    }

    public static func daysInYear(_ year: Int) -> Int? {
        guard contains(year: year) else { return nil }
        let i = year - firstYear
        return yearStarts[i + 1] - yearStarts[i]
    }

    public static func startJDN(year: Int) -> Int? {
        guard contains(year: year) else { return nil }
        return yearStarts[year - firstYear]
    }

    public static func startJDN(year: Int, month: Int) -> Int? {
        guard var jdn = startJDN(year: year), (1...12).contains(month) else { return nil }
        let row = monthLengthTable[year - firstYear]
        for m in 0..<(month - 1) { jdn += Int(row[m]) }
        return jdn
    }

    public static func toJDN(_ date: BSDate) -> Int? {
        guard let len = daysInMonth(year: date.year, month: date.month),
              date.day >= 1, date.day <= len,
              let start = startJDN(year: date.year, month: date.month) else { return nil }
        return start + date.day - 1
    }

    public static func fromJDN(_ jdn: Int) -> BSDate? {
        guard jdn >= firstJDN, jdn < endJDN else { return nil }
        var lo = 0, hi = monthLengthTable.count - 1
        while lo < hi {
            let mid = (lo + hi + 1) / 2
            if yearStarts[mid] <= jdn { lo = mid } else { hi = mid - 1 }
        }
        var remaining = jdn - yearStarts[lo]
        let row = monthLengthTable[lo]
        var month = 0
        while remaining >= Int(row[month]) {
            remaining -= Int(row[month])
            month += 1
        }
        return BSDate(year: firstYear + lo, month: month + 1, day: remaining + 1)
    }

    public static func toAD(_ date: BSDate) -> ADDate? {
        toJDN(date).map(ADDate.init(jdn:))
    }

    public static func fromAD(_ date: ADDate) -> BSDate? {
        guard date.isValid else { return nil }
        return fromJDN(date.jdn)
    }

    /// Returns the BS date `n` months after the 1st of the given month.
    public static func addMonths(_ n: Int, to year: Int, month: Int) -> (year: Int, month: Int) {
        let index = year * 12 + (month - 1) + n
        return (index / 12, index % 12 + 1)
    }
}
