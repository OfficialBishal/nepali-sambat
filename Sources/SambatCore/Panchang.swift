import Foundation

public enum Paksha: Int, Codable, Sendable {
    case shukla, krishna
}

/// A lunar (chandra) month, amanta reckoning: new moon to new moon.
public struct LunarMonth: Hashable, Sendable {
    public let lunation: Int
    public let start: Date
    public let end: Date
    /// 0 = Chaitra, 1 = Baisakh, ... 11 = Falgun
    public let index: Int
    /// A month with no solar ingress (adhik / malmas). Festivals are not held in it.
    public let isAdhik: Bool
}

/// The tithi prevailing at sunrise in Kathmandu, which is what a Nepali patro prints for the day.
public struct DayPanchang: Hashable, Sendable {
    public let jdn: Int
    public let sunrise: Date
    public let sunset: Date
    /// 1...30. 1-15 shukla paksha (15 = purnima), 16-30 krishna paksha (30 = aunsi).
    public let tithi: Int
    public let tithiEnds: Date
    /// Amanta month of the lunar day.
    public let amantaMonth: Int
    public let isAdhikMonth: Bool
    /// A tithi that begins and ends between this sunrise and the next (it is never "printed").
    public let skippedTithi: Int?

    public var paksha: Paksha { tithi <= 15 ? .shukla : .krishna }
    /// 1...15 within the fortnight.
    public var tithiInPaksha: Int { tithi <= 15 ? tithi : tithi - 15 }
    public var isPurnima: Bool { tithi == 15 }
    public var isAunsi: Bool { tithi == 30 }
    public var isEkadashi: Bool { tithiInPaksha == 11 }
    /// Nepali patros name the dark fortnight after the coming month (purnimanta).
    public var purnimantaMonth: Int { paksha == .shukla ? amantaMonth : (amantaMonth + 1) % 12 }
}

public final class Panchang: @unchecked Sendable {
    public static let shared = Panchang()

    private let lock = NSLock()
    private var newMoons: [Int: Date] = [:]
    private var days: [Int: DayPanchang] = [:]

    public init() {}

    private static let lunationEpoch = 2_451_550.09766

    public func newMoon(lunation k: Int) -> Date {
        lock.lock()
        if let d = newMoons[k] { lock.unlock(); return d }
        lock.unlock()
        let guess = Astro.date(julianDay: Self.lunationEpoch + Astro.synodicMonth * Double(k))
        let d = Astro.newMoon(near: guess)
        lock.lock()
        newMoons[k] = d
        lock.unlock()
        return d
    }

    public func lunation(containing date: Date) -> Int {
        var k = Int(((Astro.julianDay(date) - Self.lunationEpoch) / Astro.synodicMonth).rounded(.down))
        while newMoon(lunation: k) > date { k -= 1 }
        while newMoon(lunation: k + 1) <= date { k += 1 }
        return k
    }

    public func month(lunation k: Int) -> LunarMonth {
        let start = newMoon(lunation: k)
        let end = newMoon(lunation: k + 1)
        let r0 = Int(Astro.siderealSunLongitude(start) / 30)
        let r1 = Int(Astro.siderealSunLongitude(end) / 30)
        return LunarMonth(lunation: k, start: start, end: end, index: (r0 + 1) % 12, isAdhik: r0 == r1)
    }

    public func lunarMonth(containing date: Date) -> LunarMonth {
        month(lunation: lunation(containing: date))
    }

    public func lunarMonths(from: Date, to: Date) -> [LunarMonth] {
        var k = lunation(containing: from)
        var out: [LunarMonth] = []
        while true {
            let m = month(lunation: k)
            out.append(m)
            if m.end > to { break }
            k += 1
        }
        return out
    }

    /// Start and end of a tithi (1...30) inside the given lunar month.
    public func tithiSpan(_ tithi: Int, in month: LunarMonth) -> (start: Date, end: Date) {
        let perTithi = Astro.synodicMonth / 30 * 86_400
        let start = tithi == 1 ? month.start
            : Astro.elongationTime(Double(tithi - 1) * 12, near: month.start.addingTimeInterval(Double(tithi - 1) * perTithi))
        let end = tithi == 30 ? month.end
            : Astro.elongationTime(Double(tithi) * 12, near: month.start.addingTimeInterval(Double(tithi) * perTithi))
        return (start, end)
    }

    public func sunTimes(jdn: Int) -> (sunrise: Date, sunset: Date) {
        Astro.sunTimes(jdn: jdn)
    }

    public func day(_ jdn: Int) -> DayPanchang {
        lock.lock()
        if let d = days[jdn] { lock.unlock(); return d }
        lock.unlock()

        let (rise, set) = Astro.sunTimes(jdn: jdn)
        let e = Astro.elongation(rise)
        let tithi = min(30, Int(e / 12) + 1)
        let remaining = Double(tithi) * 12 - e
        let ends = tithi == 30
            ? Astro.newMoon(near: rise.addingTimeInterval(remaining / Astro.meanElongationRate * 86_400))
            : Astro.elongationTime(Double(tithi) * 12, near: rise.addingTimeInterval(remaining / Astro.meanElongationRate * 86_400))
        let month = lunarMonth(containing: rise)

        let nextRise = Astro.sunTimes(jdn: jdn + 1).sunrise
        let nextTithi = min(30, Int(Astro.elongation(nextRise) / 12) + 1)
        let step = (nextTithi - tithi + 30) % 30
        let skipped = step == 2 ? tithi % 30 + 1 : nil

        let d = DayPanchang(jdn: jdn, sunrise: rise, sunset: set, tithi: tithi, tithiEnds: ends,
                            amantaMonth: month.index, isAdhikMonth: month.isAdhik, skippedTithi: skipped)
        lock.lock()
        days[jdn] = d
        if days.count > 4000 { days.removeAll(keepingCapacity: true); days[jdn] = d }
        lock.unlock()
        return d
    }

    /// Instant of a solar ingress (sankranti) into sidereal sign `rashi` (0 = Mesh) nearest `guess`.
    public func sankranti(rashi: Int, near guess: Date) -> Date {
        Astro.siderealSunTime(Double(rashi) * 30, near: guess)
    }
}
