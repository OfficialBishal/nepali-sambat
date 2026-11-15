// Self-checks for SambatCore. Run with `swift run SambatChecks`.
// (Swift Testing/XCTest need a full Xcode install; this keeps the checks runnable with just the CLT.)
import Foundation
import SambatCore

var failures = 0
var passes = 0

func check(_ condition: @autoclosure () -> Bool, _ label: String, line: Int = #line) {
    if condition() {
        passes += 1
    } else {
        failures += 1
        print("FAIL [line \(line)]: \(label)")
    }
}

var utc = Calendar(identifier: .gregorian)
utc.timeZone = TimeZone(identifier: "UTC")!
func utcDate(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) -> Date {
    utc.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
}

// MARK: Conversion

check(BSCalendar.fromAD(ADDate(year: 2026, month: 4, day: 14)) == BSDate(year: 2083, month: 1, day: 1), "2083 new year")
check(BSCalendar.fromAD(ADDate(year: 2025, month: 4, day: 14)) == BSDate(year: 2082, month: 1, day: 1), "2082 new year")
check(BSCalendar.fromAD(ADDate(year: 1943, month: 4, day: 14)) == BSDate(year: 2000, month: 1, day: 1), "2000 new year")
check(BSCalendar.fromAD(ADDate(year: 2026, month: 11, day: 15)) == BSDate(year: 2083, month: 7, day: 29), "Nov 15 2026")
check(BSCalendar.toAD(BSDate(year: 2083, month: 7, day: 1)) == ADDate(year: 2026, month: 10, day: 18), "Kartik 1 2083")
check(BSDate(year: 2083, month: 8, day: 30).isValid == false, "Mangsir 2083 has 29 days")
check(BSDate(year: 2083, month: 13, day: 1).isValid == false, "month 13")
check(BSCalendar.fromAD(ADDate(year: 2026, month: 2, day: 30)) == nil, "Feb 30")
check(ADDate(year: 2026, month: 11, day: 15).weekday == 0, "Sunday")
check(ADDate(year: 2000, month: 1, day: 1).weekday == 6, "Saturday")

var roundTripOK = true
for jdn in BSCalendar.firstJDN..<BSCalendar.endJDN where BSDate(jdn: jdn)?.jdn != jdn { roundTripOK = false }
check(roundTripOK, "round trip every day 1975-2100 BS")

// MARK: Nepal time, the reason this app exists

let lastNepalMinute = utcDate(2026, 11, 15, 18, 14) // 23:59 in Kathmandu
let firstNepalMinute = lastNepalMinute.addingTimeInterval(60) // 00:00 in Kathmandu
check(NepalTime.today(.nepal, now: lastNepalMinute) == BSDate(year: 2083, month: 7, day: 29), "before Nepal midnight")
check(NepalTime.today(.nepal, now: firstNepalMinute) == BSDate(year: 2083, month: 7, day: 30), "after Nepal midnight")
let newYork = TimeZone(identifier: "America/New_York")!
check(BSDate(jdn: JDN.of(firstNepalMinute, in: newYork)) == BSDate(year: 2083, month: 7, day: 29), "New York is still on the old day")
check(NepalTime.nextDayChange(after: utcDate(2026, 11, 15, 15, 42), basis: .nepal) == utcDate(2026, 11, 15, 18, 15), "next change at 18:15 UTC")

// MARK: Panchang

let fullMoonDay = Panchang.shared.day(ADDate(year: 2026, month: 11, day: 24).jdn)
check(fullMoonDay.tithi == 15, "Purnima on Nov 24 2026")
check(abs(fullMoonDay.tithiEnds.timeIntervalSince(utcDate(2026, 11, 24, 14, 53))) < 180, "full moon within 3 min of 14:53 UTC")
let gaiJatraDay = Panchang.shared.day(ADDate(year: 2026, month: 8, day: 29).jdn)
check(Formatter.tithiName(gaiJatraDay, .english) == "Bhadra Krishna Pratipada", "purnimanta naming")

// MARK: Festivals (Government of Nepal holiday notices, 2082 and 2083 BS)

func festival(_ key: String, _ year: Int) -> BSDate? {
    FestivalEngine.shared.events(inYear: year).first { $0.key == key }.flatMap { BSDate(jdn: $0.jdn) }
}

let official: [(String, Int, Int, Int)] = [
    ("buddhaJayanti", 2082, 1, 29), ("eidAdha", 2082, 2, 24), ("janaiPurnima", 2082, 4, 24), ("gaiJatra", 2082, 4, 25),
    ("janmashtami", 2082, 4, 31), ("teej", 2082, 5, 10), ("indraJatra", 2082, 5, 21), ("ghatasthapana", 2082, 6, 6),
    ("fulpati", 2082, 6, 13), ("mahaAshtami", 2082, 6, 14), ("mahaNavami", 2082, 6, 15), ("dashami", 2082, 6, 16),
    ("kaagTihar", 2082, 7, 2), ("kukurTihar", 2082, 7, 3), ("laxmiPuja", 2082, 7, 4), ("govardhan", 2082, 7, 5),
    ("bhaiTika", 2082, 7, 6), ("chhath", 2082, 7, 10), ("guruNanak", 2082, 7, 19), ("udhauli", 2082, 8, 18),
    ("sonamLhosar", 2082, 10, 5), ("basantaPanchami", 2082, 10, 9), ("shivaratri", 2082, 11, 3),
    ("gyalpoLhosar", 2082, 11, 6), ("holi", 2082, 11, 18), ("holiTerai", 2082, 11, 19), ("ghodeJatra", 2082, 12, 4),
    ("eidFitr", 2082, 12, 7), ("ramNavami", 2082, 12, 13),
    ("buddhaJayanti", 2083, 1, 18), ("eidAdha", 2083, 2, 13), ("janaiPurnima", 2083, 5, 12), ("gaiJatra", 2083, 5, 13),
    ("janmashtami", 2083, 5, 19), ("teej", 2083, 5, 29), ("indraJatra", 2083, 6, 9), ("jitiya", 2083, 6, 18),
    ("ghatasthapana", 2083, 6, 25), ("fulpati", 2083, 7, 1), ("mahaAshtami", 2083, 7, 2), ("mahaNavami", 2083, 7, 3),
    ("dashami", 2083, 7, 4), ("kaagTihar", 2083, 7, 21), ("kukurTihar", 2083, 7, 22), ("laxmiPuja", 2083, 7, 22),
    ("govardhan", 2083, 7, 24), ("bhaiTika", 2083, 7, 25), ("chhath", 2083, 7, 29), ("udhauli", 2083, 9, 9),
    ("sonamLhosar", 2083, 10, 24), ("basantaPanchami", 2083, 10, 28), ("shivaratri", 2083, 11, 22),
    ("gyalpoLhosar", 2083, 11, 25), ("eidFitr", 2083, 11, 26), ("holi", 2083, 12, 7), ("holiTerai", 2083, 12, 8),
    ("ghodeJatra", 2083, 12, 23),
]
for (key, y, m, d) in official {
    let got = festival(key, y)
    check(got == BSDate(year: y, month: m, day: d), "\(key) \(y): expected \(y)-\(m)-\(d), got \(got?.description ?? "nil")")
}

let events2083 = FestivalEngine.shared.events(inYear: 2083)
for day in 22...26 {
    let jdn = BSDate(year: 2083, month: 7, day: day).jdn!
    check(events2083.contains { $0.jdn == jdn && $0.isPublicHoliday }, "Tihar holiday on Kartik \(day) 2083")
}
check(FestivalEngine.shared.nepalSambat(jdn: BSDate(year: 2083, month: 7, day: 23).jdn!) == 1146, "NS 1146 before Mha Puja")
check(FestivalEngine.shared.nepalSambat(jdn: BSDate(year: 2083, month: 7, day: 24).jdn!) == 1147, "NS 1147 from Mha Puja")

// Every supported year computes without trapping and has the fixed holidays.
var allYearsOK = true
for y in BSCalendar.firstYear...BSCalendar.lastYear {
    let ev = FestivalEngine.shared.events(inYear: y)
    if !ev.contains(where: { $0.key == "newyear" }) || !ev.contains(where: { $0.key == "dashami" }) { allYearsOK = false; print("year \(y) incomplete") }
}
check(allYearsOK, "all years have New Year and Dashain")

print("\(passes) passed, \(failures) failed")
exit(failures == 0 ? 0 : 1)
