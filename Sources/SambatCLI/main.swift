import Foundation
import SambatCore

var args = Array(CommandLine.arguments.dropFirst())
let lang: Language = {
    if let i = args.firstIndex(where: { $0 == "--en" || $0 == "-e" }) { args.remove(at: i); return .english }
    if let i = args.firstIndex(where: { $0 == "--ne" || $0 == "-n" }) { args.remove(at: i); return .nepali }
    return .nepali
}()
let basis: DateBasis = {
    if let i = args.firstIndex(of: "--local") { args.remove(at: i); return .local }
    return .nepal
}()
let npt = NepalTime.timeZone

func fmt(_ d: Date, _ tz: TimeZone = npt) -> String {
    let f = DateFormatter()
    f.timeZone = tz
    f.dateFormat = "yyyy-MM-dd HH:mm"
    return f.string(from: d)
}

func parseDate(_ s: String) -> (Int, Int, Int)? {
    let parts = s.split(whereSeparator: { "-/.".contains($0) }).compactMap { Int($0) }
    guard parts.count == 3 else { return nil }
    return (parts[0], parts[1], parts[2])
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write((message + "\n").data(using: .utf8)!)
    exit(1)
}

func describe(jdn: Int) {
    guard let bs = BSDate(jdn: jdn) else { fail("Date is outside \(BSCalendar.firstYear)–\(BSCalendar.lastYear) BS") }
    let ad = ADDate(jdn: jdn)
    let p = Panchang.shared.day(jdn)
    print("\(Formatter.dateLong(bs, lang)), \(Formatter.weekday(JDN.weekday(jdn), lang))")
    print("\(Formatter.weekday(JDN.weekday(jdn), .english)), \(Formatter.adLong(ad, .english))")
    print(Formatter.tithiName(p, lang))
    for e in FestivalEngine.shared.events(on: jdn) {
        print("• \(e.name(lang))\(e.isPublicHoliday ? (lang == .nepali ? " (बिदा)" : " (holiday)") : "")")
    }
}

func printMonth(year: Int, month: Int, today: Int) {
    guard let start = BSCalendar.startJDN(year: year, month: month),
          let len = BSCalendar.daysInMonth(year: year, month: month) else { fail("No data for \(year)/\(month)") }
    let a = ADDate(jdn: start), b = ADDate(jdn: start + len - 1)
    let title = "\(Formatter.bsMonth(month, lang)) \(Formatter.digits(year, lang))"
    print(title + "   (\(Formatter.adMonth(a.month, .english, short: true)) \(a.year) – \(Formatter.adMonth(b.month, .english, short: true)) \(b.year))")
    let header = (0..<7).map { Formatter.weekday($0, .english, short: true).prefix(2).padding(toLength: 4, withPad: " ", startingAt: 0) }
    print(header.joined())
    var line = String(repeating: " ", count: JDN.weekday(start) * 4)
    let events = FestivalEngine.shared.eventsByDay(year: year, month: month)
    for d in 1...len {
        let jdn = start + d - 1
        let holiday = JDN.weekday(jdn) == 6 || (events[jdn] ?? []).contains { $0.isPublicHoliday }
        var cell = Formatter.digits(d, lang)
        cell = String(repeating: " ", count: max(0, 2 - cell.count)) + cell
        let tty = isatty(STDOUT_FILENO) == 1
        if jdn == today && tty { cell = "\u{1B}[7m\(cell)\u{1B}[0m" } else if holiday && tty { cell = "\u{1B}[31m\(cell)\u{1B}[0m" }
        line += cell + "  "
        if JDN.weekday(jdn) == 6 { print(line); line = "" }
    }
    if !line.isEmpty { print(line) }
}

let usage = """
patro — Nepali calendar (Bikram Sambat) that follows Nepal time

  patro                      today's Nepali date (switches at midnight in Nepal)
  patro month [YYYY MM]      a BS month as a calendar
  patro ad2bs 2026-11-15     convert AD → BS
  patro bs2ad 2083-07-29     convert BS → AD
  patro upcoming [N]         the next N festivals and holidays (default 10)
  patro events [YEAR]        every festival in a BS year
  patro ics [YEAR]           iCalendar (.ics) of a BS year's festivals to stdout

  --en / --ne                English or Nepali output (default Nepali)
  --local                    use this computer's time zone instead of Nepal's
"""

let command = args.first ?? "today"
switch command {
case "today", "now":
    let now = Date()
    let jdn = NepalTime.todayJDN(basis, now: now)
    describe(jdn: jdn)
    let localJDN = JDN.of(now, in: .current)
    print((lang == .nepali ? "नेपाल समय: " : "Nepal time: ") + Formatter.time(now, in: npt, lang))
    if basis == .nepal && localJDN != jdn {
        print(lang == .nepali ? "(नेपालमा मिति फेरिइसक्यो; यहाँको ईस्वी मिति अझै \(Formatter.adLong(ADDate(jdn: localJDN), .english)) हो)"
                              : "(Nepal has already moved on; it's still \(Formatter.adLong(ADDate(jdn: localJDN), .english)) here)")
    }

case "month", "cal":
    let today = NepalTime.todayJDN(basis)
    let t = BSDate(jdn: today)!
    let y = args.count > 2 ? Int(args[1]) ?? t.year : t.year
    let m = args.count > 2 ? Int(args[2]) ?? t.month : (args.count > 1 ? Int(args[1]) ?? t.month : t.month)
    printMonth(year: y, month: m, today: today)

case "ad2bs", "ad":
    let input: (Int, Int, Int)? = args.count == 2 ? parseDate(args[1]) : (args.count == 4 ? (Int(args[1]) ?? 0, Int(args[2]) ?? 0, Int(args[3]) ?? 0) : nil)
    guard let (y, m, d) = input, ADDate(year: y, month: m, day: d).isValid else { fail("usage: patro ad2bs YYYY-MM-DD") }
    describe(jdn: ADDate(year: y, month: m, day: d).jdn)

case "bs2ad", "bs":
    let input: (Int, Int, Int)? = args.count == 2 ? parseDate(args[1]) : (args.count == 4 ? (Int(args[1]) ?? 0, Int(args[2]) ?? 0, Int(args[3]) ?? 0) : nil)
    guard let (y, m, d) = input, let jdn = BSDate(year: y, month: m, day: d).jdn else { fail("usage: patro bs2ad YYYY-MM-DD (valid BS date)") }
    describe(jdn: jdn)

case "upcoming", "next":
    let n = args.count > 1 ? Int(args[1]) ?? 10 : 10
    let today = NepalTime.todayJDN(basis)
    var seen = Set<String>()
    let list = FestivalEngine.shared.events(from: today, to: today + 400)
        .filter { $0.category != .observance && seen.insert("\($0.jdn)\($0.nameEn)").inserted }
        .prefix(n)
    for e in list {
        let bs = BSDate(jdn: e.jdn)!
        let ad = ADDate(jdn: e.jdn)
        let date = "\(Formatter.bsMonth(bs.month, lang)) \(Formatter.digits(bs.day, lang))"
        print("\(date.padding(toLength: 12, withPad: " ", startingAt: 0)) \(Formatter.adShort(ad, .english).padding(toLength: 7, withPad: " ", startingAt: 0))  \(e.name(lang))\(e.isPublicHoliday ? " ★" : "")  (\(Formatter.relativeDays(e.jdn - today, lang)))")
    }

case "events":
    let year = args.count > 1 ? Int(args[1])! : NepalTime.today()!.year
    for e in FestivalEngine.shared.events(inYear: year) {
        let bs = BSDate(jdn: e.jdn)!
        let ad = ADDate(jdn: e.jdn)
        print(String(format: "%d/%02d/%02d  %04d-%02d-%02d  ", bs.year, bs.month, bs.day, ad.year, ad.month, ad.day),
              e.category.rawValue.padding(toLength: 16, withPad: " ", startingAt: 0), e.nameEn, "|", e.nameNe, "#\(e.key)")
    }

case "ics":
    let year = args.count > 1 ? Int(args[1]) ?? NepalTime.today()!.year : NepalTime.today()!.year
    let years = args.count > 2 ? Int(args[2]) ?? 1 : 1
    guard let from = BSCalendar.startJDN(year: year) else { fail("No data for \(year)") }
    let to = BSCalendar.startJDN(year: year + years) ?? BSCalendar.endJDN
    print(ICS.calendar(from: from, to: to, lang: lang, name: lang == .nepali ? "नेपाली चाडपर्व" : "Nepali Festivals"), terminator: "")

// Developer diagnostics
case "day":
    let bs = BSDate(year: Int(args[1])!, month: Int(args[2])!, day: Int(args[3])!)
    let n = args.count > 4 ? Int(args[4])! : 1
    let base = bs.jdn!
    for jdn in base..<(base + n) {
        let p = Panchang.shared.day(jdn)
        print(BSDate(jdn: jdn)!, ADDate(jdn: jdn), Formatter.weekday(JDN.weekday(jdn), .english, short: true),
              Formatter.tithiName(p, .english), "ends", fmt(p.tithiEnds), "| rise", fmt(p.sunrise), "set", fmt(p.sunset),
              p.skippedTithi.map { "| skips \($0)" } ?? "")
    }

case "sankranti":
    let from = args.count > 1 ? Int(args[1])! : 2000
    let to = args.count > 2 ? Int(args[2])! : 2100
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = npt
    for y in from...to {
        for m in 1...12 {
            guard let start = BSCalendar.startJDN(year: y, month: m) else { continue }
            let s = Panchang.shared.sankranti(rashi: m - 1, near: JDN.startOfDay(start, in: npt))
            let c = cal.dateComponents([.hour, .minute], from: s)
            print(y, m, start - JDN.of(s, in: npt), c.hour! * 60 + c.minute!)
        }
    }

case "help", "-h", "--help":
    print(usage)

default:
    print(usage)
    exit(1)
}
