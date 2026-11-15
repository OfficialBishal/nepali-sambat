import Foundation

/// Compact positional astronomy (after Jean Meeus, "Astronomical Algorithms").
/// Accurate to roughly a minute of time for tithi boundaries, which is all a panchang needs.
public enum Astro {
    static let d2r = Double.pi / 180
    static let synodicMonth = 29.530588861
    static let meanElongationRate = 360.0 / 29.530588861 // deg/day
    static let meanSunRate = 0.98564736 // deg/day

    public static func julianDay(_ date: Date) -> Double {
        date.timeIntervalSince1970 / 86_400 + 2_440_587.5
    }

    public static func date(julianDay jd: Double) -> Date {
        Date(timeIntervalSince1970: (jd - 2_440_587.5) * 86_400)
    }

    /// TT − UT in seconds. A coarse fit is plenty here: 10 s of error moves the Moon by ~5″.
    static func deltaT(jd: Double) -> Double {
        let y = 2000 + (jd - 2_451_545) / 365.25
        switch y {
        case ..<1950: return 29
        case ..<1986: return 29 + (y - 1950) * 0.72
        case ..<2025: return 55 + (y - 1986) * 0.36
        default: return 69 + (y - 2025) * 0.3
        }
    }

    static func centuriesTT(_ jdUT: Double) -> Double {
        (jdUT + deltaT(jd: jdUT) / 86_400 - 2_451_545) / 36_525
    }

    static func norm(_ x: Double) -> Double {
        let r = x.truncatingRemainder(dividingBy: 360)
        return r < 0 ? r + 360 : r
    }

    static func signed(_ x: Double) -> Double {
        let n = norm(x)
        return n > 180 ? n - 360 : n
    }

    // MARK: Sun

    /// Apparent geocentric longitude of the Sun (tropical, degrees).
    static func sunLongitude(T: Double) -> Double {
        let L0 = 280.46646 + 36_000.76983 * T + 0.0003032 * T * T
        let M = (357.52911 + 35_999.05029 * T - 0.0001537 * T * T) * d2r
        let C = (1.914602 - 0.004817 * T - 0.000014 * T * T) * sin(M)
            + (0.019993 - 0.000101 * T) * sin(2 * M)
            + 0.000289 * sin(3 * M)
        let omega = (125.04 - 1934.136 * T) * d2r
        return norm(L0 + C - 0.00569 - 0.00478 * sin(omega))
    }

    public static func sunLongitude(_ date: Date) -> Double {
        sunLongitude(T: centuriesTT(julianDay(date)))
    }

    /// Lahiri (Chitrapaksha) ayanamsa, degrees.
    static func lahiriAyanamsa(T: Double) -> Double {
        23.85709 + 1.396971278 * T + 0.0003086 * T * T
    }

    /// Sidereal (nirayana) longitude of the Sun, used for sankrantis and lunar month names.
    public static func siderealSunLongitude(_ date: Date) -> Double {
        let T = centuriesTT(julianDay(date))
        return norm(sunLongitude(T: T) - lahiriAyanamsa(T: T))
    }

    // MARK: Moon

    private struct MoonTerm {
        let d: Double, m: Double, mp: Double, f: Double, coef: Double
    }

    // Meeus table 47.A, longitude terms (unit: 1e-6 degree).
    private static let moonTerms: [MoonTerm] = [
        (0, 0, 1, 0, 6_288_774), (2, 0, -1, 0, 1_274_027), (2, 0, 0, 0, 658_314),
        (0, 0, 2, 0, 213_618), (0, 1, 0, 0, -185_116), (0, 0, 0, 2, -114_332),
        (2, 0, -2, 0, 58_793), (2, -1, -1, 0, 57_066), (2, 0, 1, 0, 53_322),
        (2, -1, 0, 0, 45_758), (0, 1, -1, 0, -40_923), (1, 0, 0, 0, -34_720),
        (0, 1, 1, 0, -30_383), (2, 0, 0, -2, 15_327), (0, 0, 1, 2, -12_528),
        (0, 0, 1, -2, 10_980), (4, 0, -1, 0, 10_675), (0, 0, 3, 0, 10_034),
        (4, 0, -2, 0, 8_548), (2, 1, -1, 0, -7_888), (2, 1, 0, 0, -6_766),
        (1, 0, -1, 0, -5_163), (1, 1, 0, 0, 4_987), (2, -1, 1, 0, 4_036),
        (2, 0, 2, 0, 3_994), (4, 0, 0, 0, 3_861), (2, 0, -3, 0, 3_665),
        (0, 1, -2, 0, -2_689), (2, 0, -1, 2, -2_602), (2, -1, -2, 0, 2_390),
        (1, 0, 1, 0, -2_348), (2, -2, 0, 0, 2_236), (0, 1, 2, 0, -2_120),
        (0, 2, 0, 0, -2_069), (2, -2, -1, 0, 2_048), (2, 0, 1, -2, -1_773),
        (2, 0, 0, 2, -1_595), (4, -1, -1, 0, 1_215), (0, 0, 2, 2, -1_110),
        (3, 0, -1, 0, -892), (2, 1, 1, 0, -810), (4, -1, -2, 0, 759),
        (0, 2, -1, 0, -713), (2, 2, -1, 0, -700), (2, 1, -2, 0, 691),
        (2, -1, 0, -2, 596), (4, 0, 1, 0, 549), (0, 0, 4, 0, 537),
        (4, -1, 0, 0, 520), (1, 0, -2, 0, -487), (2, 1, 0, -2, -399),
        (0, 0, 2, -2, -381), (1, 1, 1, 0, 351), (3, 0, -2, 0, -340),
        (4, 0, -3, 0, 330), (2, -1, 2, 0, 327), (0, 2, 1, 0, -323),
        (1, 1, -1, 0, 299), (2, 0, 3, 0, 294),
    ].map { MoonTerm(d: $0.0, m: $0.1, mp: $0.2, f: $0.3, coef: $0.4) }

    /// Apparent geocentric longitude of the Moon (tropical, degrees).
    static func moonLongitude(T: Double) -> Double {
        let T2 = T * T, T3 = T2 * T, T4 = T3 * T
        let Lp = 218.3164477 + 481_267.88123421 * T - 0.0015786 * T2 + T3 / 538_841 - T4 / 65_194_000
        let D = 297.8501921 + 445_267.1114034 * T - 0.0018819 * T2 + T3 / 545_868 - T4 / 113_065_000
        let M = 357.5291092 + 35_999.0502909 * T - 0.0001536 * T2 + T3 / 24_490_000
        let Mp = 134.9633964 + 477_198.8675055 * T + 0.0087414 * T2 + T3 / 69_699 - T4 / 14_712_000
        let F = 93.2720950 + 483_202.0175233 * T - 0.0036539 * T2 - T3 / 3_526_000 + T4 / 863_310_000
        let A1 = 119.75 + 131.849 * T
        let A2 = 53.09 + 479_264.290 * T
        let E = 1 - 0.002516 * T - 0.0000074 * T2

        var sum = 0.0
        for t in moonTerms {
            var c = t.coef
            switch abs(t.m) {
            case 1: c *= E
            case 2: c *= E * E
            default: break
            }
            sum += c * sin((t.d * D + t.m * M + t.mp * Mp + t.f * F) * d2r)
        }
        sum += 3958 * sin(A1 * d2r) + 1962 * sin((Lp - F) * d2r) + 318 * sin(A2 * d2r)
        let omega = (125.04 - 1934.136 * T) * d2r
        return norm(Lp + sum / 1_000_000 - 0.00478 * sin(omega))
    }

    public static func moonLongitude(_ date: Date) -> Double {
        moonLongitude(T: centuriesTT(julianDay(date)))
    }

    /// Moon − Sun, 0..<360 degrees. Each 12° is one tithi.
    public static func elongation(_ date: Date) -> Double {
        let T = centuriesTT(julianDay(date))
        return norm(moonLongitude(T: T) - sunLongitude(T: T))
    }

    // MARK: Solvers

    /// Instant near `guess` at which the Moon−Sun elongation equals `target` degrees.
    public static func elongationTime(_ target: Double, near guess: Date) -> Date {
        var t = julianDay(guess)
        for _ in 0..<12 {
            let e = signed(elongation(date(julianDay: t)) - target)
            let dt = -e / meanElongationRate
            t += dt
            if abs(dt) < 1e-6 { break }
        }
        return date(julianDay: t)
    }

    /// The new moon (amavasya end) nearest to `date`.
    public static func newMoon(near date: Date) -> Date {
        elongationTime(0, near: date)
    }

    /// The last new moon at or before `date`.
    public static func newMoon(before date: Date) -> Date {
        let e = elongation(date)
        var nm = elongationTime(0, near: date.addingTimeInterval(-e / meanElongationRate * 86_400))
        if nm > date { nm = elongationTime(0, near: nm.addingTimeInterval(-synodicMonth * 86_400)) }
        return nm
    }

    /// Instant near `guess` at which the sidereal Sun reaches `target` degrees (a sankranti when target is a multiple of 30).
    public static func siderealSunTime(_ target: Double, near guess: Date) -> Date {
        var t = julianDay(guess)
        for _ in 0..<12 {
            let e = signed(siderealSunLongitude(date(julianDay: t)) - target)
            let dt = -e / meanSunRate
            t += dt
            if abs(dt) < 1e-6 { break }
        }
        return date(julianDay: t)
    }

    // MARK: Sunrise / sunset

    /// Sunrise and sunset for a civil day at the given location (default: Kathmandu).
    public static func sunTimes(jdn: Int, latitude: Double = NepalTime.latitude, longitude: Double = NepalTime.longitude)
        -> (sunrise: Date, sunset: Date)
    {
        let n = Double(jdn - 2_451_545) + 0.0008
        let jStar = n - longitude / 360
        let M = norm(357.5291 + 0.98560028 * jStar)
        let Mr = M * d2r
        let C = 1.9148 * sin(Mr) + 0.0200 * sin(2 * Mr) + 0.0003 * sin(3 * Mr)
        let lambda = norm(M + C + 180 + 102.9372) * d2r
        let jTransit = 2_451_545 + jStar + 0.0053 * sin(Mr) - 0.0069 * sin(2 * lambda)
        let sinDec = sin(lambda) * sin(23.4397 * d2r)
        let cosDec = cos(asin(sinDec))
        let phi = latitude * d2r
        let cosH = (sin(-0.833 * d2r) - sin(phi) * sinDec) / (cos(phi) * cosDec)
        let h = acos(max(-1, min(1, cosH))) / d2r
        return (date(julianDay: jTransit - h / 360), date(julianDay: jTransit + h / 360))
    }
}
