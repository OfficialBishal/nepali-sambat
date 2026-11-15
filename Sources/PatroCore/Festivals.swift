import Foundation

public enum EventCategory: String, Codable, Sendable, CaseIterable {
    /// National public holiday (shown in red).
    case publicHoliday
    /// Holiday for a region or community only (valley, Terai, women, Muslim community...).
    case regionalHoliday
    /// A festival or cultural day without a holiday.
    case festival
    /// Jayanti, international days and other observances.
    case observance
}

public struct CalendarEvent: Hashable, Codable, Identifiable, Sendable {
    public let key: String
    public let nameNe: String
    public let nameEn: String
    public let category: EventCategory
    public let jdn: Int
    public let noteNe: String?
    public let noteEn: String?

    public var id: String { "\(key)-\(jdn)" }
    public var isPublicHoliday: Bool { category == .publicHoliday }
    public var isHoliday: Bool { category == .publicHoliday || category == .regionalHoliday }

    public func name(_ lang: Language) -> String { lang == .nepali ? nameNe : nameEn }
    public func note(_ lang: Language) -> String? { lang == .nepali ? noteNe : noteEn }
}

/// When a tithi has to prevail for a festival to be held on a given day.
enum Observance {
    /// Udaya tithi: the tithi at sunrise (the default in Nepal).
    case sunrise
    /// Madhyahna: midday.
    case noon
    /// Aparahna: afternoon.
    case afternoon
    /// Pradosh: at sunset.
    case sunset
    /// Nishita: around midnight.
    case midnight
    /// Like the wrapped rule, but when the tithi covers that moment on two days, take the later day
    /// (Maha Navami, Vijaya Dashami and Laxmi Puja are reckoned this way in the Nepali patro).
    indirect case later(Observance)
}

/// A run of consecutive holidays (e.g. Dashain: Fulpati through Dwadashi). Days in the run
/// that have no holiday of their own get a generic entry, so tithi vriddhi never leaves a gap.
struct HolidayBlock {
    let from: String
    let to: String
    let extraDays: Int
    let ne: String
    let en: String
}

enum EventRule {
    /// Fixed Bikram Sambat date.
    case bs(month: Int, day: Int)
    /// Fixed Gregorian date.
    case ad(month: Int, day: Int)
    /// Lunar date. `month` is amanta (0 = Chaitra), `tithi` 1...30.
    case lunar(month: Int, tithi: Int, at: Observance)
    /// N days after another event in the same year.
    case after(key: String, days: Int)
    /// Hijri date, using a first-crescent estimate for Nepal.
    case hijri(month: Int, day: Int)
}

struct EventDefinition {
    let key: String
    let ne: String
    let en: String
    let category: EventCategory
    let rule: EventRule
    var noteNe: String? = nil
    var noteEn: String? = nil
}

public final class FestivalEngine: @unchecked Sendable {
    public static let shared = FestivalEngine()

    private let panchang: Panchang
    private let lock = NSLock()
    private var cache: [Int: [CalendarEvent]] = [:]
    private let npt = NepalTime.timeZone

    public init(panchang: Panchang = .shared) {
        self.panchang = panchang
    }

    // MARK: Public API

    public func events(inYear year: Int) -> [CalendarEvent] {
        lock.lock()
        if let c = cache[year] { lock.unlock(); return c }
        lock.unlock()
        let computed = compute(year: year)
        lock.lock()
        cache[year] = computed
        lock.unlock()
        return computed
    }

    public func events(on jdn: Int) -> [CalendarEvent] {
        guard let bs = BSDate(jdn: jdn) else { return [] }
        return events(inYear: bs.year).filter { $0.jdn == jdn }
    }

    /// Events with `from <= jdn < to`.
    public func events(from: Int, to: Int) -> [CalendarEvent] {
        guard let a = BSDate(jdn: max(from, BSCalendar.firstJDN)),
              let b = BSDate(jdn: min(to - 1, BSCalendar.endJDN - 1)) else { return [] }
        return (a.year...b.year).flatMap { events(inYear: $0) }.filter { $0.jdn >= from && $0.jdn < to }
    }

    public func eventsByDay(year: Int, month: Int) -> [Int: [CalendarEvent]] {
        guard let start = BSCalendar.startJDN(year: year, month: month),
              let len = BSCalendar.daysInMonth(year: year, month: month) else { return [:] }
        return Dictionary(grouping: events(inYear: year).filter { $0.jdn >= start && $0.jdn < start + len }, by: \.jdn)
    }

    /// Nepal Sambat year for a day: it turns over on Mha Puja (Kartik shukla pratipada).
    public func nepalSambat(jdn: Int) -> Int? {
        guard let bs = BSDate(jdn: jdn) else { return nil }
        guard let mhaPuja = events(inYear: bs.year).first(where: { $0.key == "govardhan" }) else { return bs.year - 937 }
        return jdn >= mhaPuja.jdn ? bs.year - 936 : bs.year - 937
    }

    // MARK: Computation

    private func compute(year: Int) -> [CalendarEvent] {
        guard let start = BSCalendar.startJDN(year: year), let len = BSCalendar.daysInYear(year) else { return [] }
        let end = start + len
        let range = start..<end
        let months = panchang.lunarMonths(from: JDN.startOfDay(start - 40, in: npt), to: JDN.startOfDay(end + 40, in: npt))

        var out: [CalendarEvent] = []
        var firstByKey: [String: Int] = [:]

        func add(_ def: EventDefinition, _ jdn: Int) {
            guard range.contains(jdn) else { return }
            out.append(CalendarEvent(key: def.key, nameNe: def.ne, nameEn: def.en, category: def.category,
                                     jdn: jdn, noteNe: def.noteNe, noteEn: def.noteEn))
            if firstByKey[def.key] == nil { firstByKey[def.key] = jdn }
        }

        for def in Self.definitions {
            switch def.rule {
            case let .bs(m, d):
                if let j = BSCalendar.toJDN(BSDate(year: year, month: m, day: d)) { add(def, j) }
            case let .ad(m, d):
                let y0 = ADDate(jdn: start).year, y1 = ADDate(jdn: end - 1).year
                for y in y0...y1 { add(def, JDN.from(year: y, month: m, day: d)) }
            case let .lunar(month, tithi, at):
                for lm in months where !lm.isAdhik && lm.index == month {
                    add(def, observanceDay(panchang.tithiSpan(tithi, in: lm), at))
                }
            case let .hijri(month, day):
                for j in hijriDays(month: month, day: day, months: months) { add(def, j) }
            case .after:
                continue
            }
        }
        for def in Self.definitions {
            if case let .after(key, days) = def.rule, let base = firstByKey[key] { add(def, base + days) }
        }
        for block in Self.holidayBlocks {
            guard let a = firstByKey[block.from], let b = firstByKey[block.to], a <= b else { continue }
            for jdn in a...(b + block.extraDays) where !out.contains(where: { $0.jdn == jdn && $0.isPublicHoliday }) {
                add(EventDefinition(key: "\(block.from)Block", ne: block.ne, en: block.en, category: .publicHoliday,
                                    rule: .after(key: block.from, days: 0)), jdn)
            }
        }

        let order = Dictionary(uniqueKeysWithValues: Self.definitions.enumerated().map { ($1.key, $0) })
        return out.sorted { ($0.jdn, order[$0.key] ?? Int.max) < ($1.jdn, order[$1.key] ?? Int.max) }
    }

    private func moment(_ jdn: Int, _ at: Observance) -> Date {
        let (rise, set) = panchang.sunTimes(jdn: jdn)
        let day = set.timeIntervalSince(rise)
        switch at {
        case .sunrise: return rise
        case .noon: return rise.addingTimeInterval(day * 0.5)
        case .afternoon: return rise.addingTimeInterval(day * 0.7)
        case .sunset: return set
        case .midnight:
            let nextRise = panchang.sunTimes(jdn: jdn + 1).sunrise
            return set.addingTimeInterval(nextRise.timeIntervalSince(set) / 2)
        case let .later(inner): return moment(jdn, inner)
        }
    }

    /// The civil day on which a tithi is observed.
    func observanceDay(_ span: (start: Date, end: Date), _ at: Observance) -> Int {
        let first = JDN.of(span.start, in: npt) - 1
        let last = JDN.of(span.end, in: npt) + 1
        if case .later = at {
            for d in (first...last).reversed() {
                let t = moment(d, at)
                if t >= span.start && t < span.end { return d }
            }
        }
        for d in first...last {
            let t = moment(d, at)
            if t >= span.start && t < span.end { return d }
        }
        // Kshaya: the tithi falls between two observance moments; keep it on the day it occurs.
        for d in first...last where moment(d, at) < span.start && moment(d + 1, at) >= span.end {
            return d
        }
        return JDN.of(span.start, in: npt)
    }

    private func hijriDays(month: Int, day: Int, months: [LunarMonth]) -> [Int] {
        var result: [Int] = []
        for lm in months {
            let nmDay = JDN.of(lm.start, in: npt)
            guard Self.tabularHijri(jdn: nmDay + 15).month == month else { continue }
            // First evening in Kathmandu when the crescent is old enough to be sighted.
            var d = nmDay
            while d < nmDay + 4 {
                let set = panchang.sunTimes(jdn: d).sunset
                if set.timeIntervalSince(lm.start) >= 15 * 3600 { break }
                d += 1
            }
            result.append(d + 1 + (day - 1))
        }
        return result
    }

    /// Arithmetic (tabular) Islamic calendar, only used to identify which lunation is which Hijri month.
    static func tabularHijri(jdn: Int) -> (year: Int, month: Int, day: Int) {
        let l0 = jdn - 1_948_440 + 10_632
        let n = (l0 - 1) / 10_631
        let l1 = l0 - 10_631 * n + 354
        let j = ((10_985 - l1) / 5316) * ((50 * l1) / 17_719) + (l1 / 5670) * ((43 * l1) / 15_238)
        let l2 = l1 - ((30 - j) / 15) * ((17_719 * j) / 50) - (j / 16) * ((15_238 * j) / 43) + 29
        let m = (24 * l2) / 709
        let d = l2 - (709 * m) / 24
        let y = 30 * n + j - 30
        return (y, m, d)
    }
}

// MARK: - Event catalogue

extension FestivalEngine {
    static let holidayBlocks: [HolidayBlock] = [
        HolidayBlock(from: "fulpati", to: "dashami", extraDays: 2, ne: "दशैं बिदा", en: "Dashain holiday"),
        HolidayBlock(from: "laxmiPuja", to: "bhaiTika", extraDays: 1, ne: "तिहार बिदा", en: "Tihar holiday"),
    ]

    // Lunar month indices (amanta): 0 Chaitra, 1 Baisakh, 2 Jestha, 3 Asar, 4 Shrawan, 5 Bhadra,
    // 6 Ashwin, 7 Kartik, 8 Mangsir, 9 Poush, 10 Magh, 11 Falgun.
    // Tithi 1-15 = shukla (15 purnima), 16-30 = krishna (30 aunsi). Nepali patros name the krishna
    // paksha after the *next* month, so "Bhadra Krishna Ashtami" is month 4 (Shrawan), tithi 23.
    static let definitions: [EventDefinition] = [
        // Fixed BS dates
        .init(key: "newyear", ne: "नयाँ वर्ष", en: "Nepali New Year", category: .publicHoliday, rule: .bs(month: 1, day: 1)),
        .init(key: "loktantra", ne: "लोकतन्त्र दिवस", en: "Loktantra Diwas", category: .observance, rule: .bs(month: 1, day: 11)),
        .init(key: "ganatantra", ne: "गणतन्त्र दिवस", en: "Republic Day", category: .publicHoliday, rule: .bs(month: 2, day: 15)),
        .init(key: "dhanDiwas", ne: "राष्ट्रिय धान दिवस (असार १५)", en: "National Paddy Day (Asar 15)", category: .festival, rule: .bs(month: 3, day: 15)),
        .init(key: "saune", ne: "साउने संक्रान्ति", en: "Saune Sankranti", category: .festival, rule: .bs(month: 4, day: 1)),
        .init(key: "constitution", ne: "संविधान दिवस", en: "Constitution Day", category: .publicHoliday, rule: .bs(month: 6, day: 3)),
        .init(key: "tamuLhosar", ne: "तमु ल्होसार", en: "Tamu Lhosar", category: .publicHoliday, rule: .bs(month: 9, day: 15)),
        .init(key: "prithvi", ne: "पृथ्वी जयन्ती / राष्ट्रिय एकता दिवस", en: "Prithvi Jayanti / National Unity Day", category: .publicHoliday, rule: .bs(month: 9, day: 27)),
        .init(key: "maghe", ne: "माघे संक्रान्ति", en: "Maghe Sankranti", category: .publicHoliday, rule: .bs(month: 10, day: 1)),
        .init(key: "shahid", ne: "शहीद दिवस", en: "Martyrs' Day", category: .publicHoliday, rule: .bs(month: 10, day: 16)),
        .init(key: "prajatantra", ne: "प्रजातन्त्र दिवस", en: "Democracy Day", category: .publicHoliday, rule: .bs(month: 11, day: 7)),

        // Fixed Gregorian dates
        .init(key: "adNewYear", ne: "अंग्रेजी नयाँ वर्ष", en: "New Year's Day (AD)", category: .observance, rule: .ad(month: 1, day: 1)),
        .init(key: "womensDay", ne: "अन्तर्राष्ट्रिय नारी दिवस", en: "International Women's Day", category: .publicHoliday, rule: .ad(month: 3, day: 8)),
        .init(key: "labourDay", ne: "अन्तर्राष्ट्रिय श्रमिक दिवस", en: "International Labour Day", category: .publicHoliday, rule: .ad(month: 5, day: 1)),
        .init(key: "christmas", ne: "क्रिसमस", en: "Christmas", category: .publicHoliday, rule: .ad(month: 12, day: 25)),

        // Chaitra / Baisakh / Jestha
        .init(key: "chaiteDashain", ne: "चैते दशैं", en: "Chaite Dashain", category: .festival, rule: .lunar(month: 0, tithi: 8, at: .sunrise)),
        .init(key: "ramNavami", ne: "श्रीराम नवमी", en: "Ram Navami", category: .publicHoliday, rule: .lunar(month: 0, tithi: 9, at: .sunrise)),
        .init(key: "hanumanJayanti", ne: "हनुमान जयन्ती", en: "Hanuman Jayanti", category: .observance, rule: .lunar(month: 0, tithi: 15, at: .sunrise)),
        .init(key: "mataTirtha", ne: "मातातीर्थ औंसी (आमाको मुख हेर्ने दिन)", en: "Mata Tirtha Aunsi (Mother's Day)", category: .festival, rule: .lunar(month: 0, tithi: 30, at: .sunrise)),
        .init(key: "buddhaJayanti", ne: "बुद्ध जयन्ती / उभौली पर्व", en: "Buddha Jayanti / Ubhauli", category: .publicHoliday, rule: .lunar(month: 1, tithi: 15, at: .sunrise)),
        .init(key: "sithiNakha", ne: "सिथि नख:", en: "Sithi Nakha", category: .festival, rule: .lunar(month: 2, tithi: 6, at: .sunrise)),

        // Asar / Shrawan
        .init(key: "harishayani", ne: "हरिशयनी एकादशी", en: "Harishayani Ekadashi", category: .observance, rule: .lunar(month: 3, tithi: 11, at: .sunrise)),
        .init(key: "guruPurnima", ne: "गुरु पूर्णिमा", en: "Guru Purnima", category: .observance, rule: .lunar(month: 3, tithi: 15, at: .sunrise)),
        .init(key: "ghantakarna", ne: "घण्टाकर्ण चतुर्दशी (गठेमंगल)", en: "Ghantakarna (Gathemangal)", category: .festival, rule: .lunar(month: 3, tithi: 29, at: .sunrise)),
        .init(key: "nagPanchami", ne: "नाग पञ्चमी", en: "Nag Panchami", category: .festival, rule: .lunar(month: 4, tithi: 5, at: .sunrise)),
        .init(key: "janaiPurnima", ne: "जनै पूर्णिमा / रक्षा बन्धन", en: "Janai Purnima / Raksha Bandhan", category: .publicHoliday, rule: .lunar(month: 4, tithi: 15, at: .sunrise)),
        .init(key: "gaiJatra", ne: "गाईजात्रा", en: "Gai Jatra", category: .regionalHoliday, rule: .lunar(month: 4, tithi: 16, at: .sunrise),
              noteNe: "काठमाडौं उपत्यकामा बिदा", noteEn: "Holiday in Kathmandu Valley"),
        .init(key: "janmashtami", ne: "श्रीकृष्ण जन्माष्टमी", en: "Krishna Janmashtami", category: .publicHoliday, rule: .lunar(month: 4, tithi: 23, at: .sunrise)),
        .init(key: "kusheAunsi", ne: "कुशे औंसी (बुबाको मुख हेर्ने दिन)", en: "Kushe Aunsi (Father's Day)", category: .festival, rule: .lunar(month: 4, tithi: 30, at: .sunrise)),

        // Bhadra
        .init(key: "teej", ne: "हरितालिका तीज", en: "Haritalika Teej", category: .regionalHoliday, rule: .lunar(month: 5, tithi: 3, at: .sunrise),
              noteNe: "महिलाहरूका लागि बिदा", noteEn: "Holiday for women"),
        .init(key: "rishiPanchami", ne: "ऋषि पञ्चमी", en: "Rishi Panchami", category: .festival, rule: .lunar(month: 5, tithi: 5, at: .sunrise)),
        .init(key: "indraJatra", ne: "इन्द्रजात्रा", en: "Indra Jatra", category: .regionalHoliday, rule: .lunar(month: 5, tithi: 14, at: .sunrise),
              noteNe: "काठमाडौं उपत्यकामा बिदा", noteEn: "Holiday in Kathmandu Valley"),
        .init(key: "jitiya", ne: "जितिया पर्व", en: "Jitiya", category: .regionalHoliday, rule: .lunar(month: 5, tithi: 23, at: .sunrise),
              noteNe: "जितिया मनाउने महिलाहरूका लागि बिदा", noteEn: "Holiday for women observing Jitiya"),

        // Ashwin — Dashain
        .init(key: "ghatasthapana", ne: "घटस्थापना", en: "Ghatasthapana", category: .publicHoliday, rule: .lunar(month: 6, tithi: 1, at: .sunrise)),
        .init(key: "fulpati", ne: "फूलपाती", en: "Fulpati", category: .publicHoliday, rule: .lunar(month: 6, tithi: 7, at: .sunrise)),
        .init(key: "mahaAshtami", ne: "महाअष्टमी", en: "Maha Ashtami", category: .publicHoliday, rule: .lunar(month: 6, tithi: 8, at: .sunrise)),
        .init(key: "mahaNavami", ne: "महानवमी", en: "Maha Navami", category: .publicHoliday, rule: .lunar(month: 6, tithi: 9, at: .later(.noon))),
        .init(key: "dashami", ne: "विजया दशमी", en: "Vijaya Dashami", category: .publicHoliday, rule: .lunar(month: 6, tithi: 10, at: .later(.afternoon))),
        .init(key: "kojagrat", ne: "कोजाग्रत पूर्णिमा", en: "Kojagrat Purnima", category: .festival, rule: .lunar(month: 6, tithi: 15, at: .sunrise)),

        // Tihar
        .init(key: "kaagTihar", ne: "काग तिहार", en: "Kaag Tihar", category: .festival, rule: .lunar(month: 6, tithi: 28, at: .sunrise)),
        .init(key: "kukurTihar", ne: "कुकुर तिहार", en: "Kukur Tihar", category: .festival, rule: .lunar(month: 6, tithi: 29, at: .sunrise)),
        .init(key: "laxmiPuja", ne: "लक्ष्मी पूजा", en: "Laxmi Puja", category: .publicHoliday, rule: .lunar(month: 6, tithi: 30, at: .later(.sunset))),
        .init(key: "govardhan", ne: "गोवर्धन पूजा / म्ह पूजा / नेपाल संवत् नयाँ वर्ष", en: "Govardhan Puja / Mha Puja / Nepal Sambat New Year", category: .publicHoliday, rule: .lunar(month: 7, tithi: 1, at: .sunrise)),
        .init(key: "bhaiTika", ne: "भाइटीका", en: "Bhai Tika", category: .publicHoliday, rule: .lunar(month: 7, tithi: 2, at: .sunrise)),
        .init(key: "chhath", ne: "छठ पर्व", en: "Chhath", category: .publicHoliday, rule: .lunar(month: 7, tithi: 6, at: .sunset)),
        .init(key: "haribodhini", ne: "हरिबोधिनी एकादशी", en: "Haribodhini Ekadashi", category: .observance, rule: .lunar(month: 7, tithi: 11, at: .sunrise)),
        .init(key: "guruNanak", ne: "गुरु नानक जयन्ती / कार्तिक पूर्णिमा", en: "Guru Nanak Jayanti / Kartik Purnima", category: .observance, rule: .lunar(month: 7, tithi: 15, at: .sunrise)),
        .init(key: "balaChaturdashi", ne: "बाला चतुर्दशी", en: "Bala Chaturdashi", category: .festival, rule: .lunar(month: 7, tithi: 29, at: .sunrise)),

        // Mangsir / Poush / Magh / Falgun
        .init(key: "vivahPanchami", ne: "विवाह पञ्चमी", en: "Vivah Panchami", category: .festival, rule: .lunar(month: 8, tithi: 5, at: .sunrise)),
        .init(key: "udhauli", ne: "उधौली पर्व / योमरी पुन्ही", en: "Udhauli / Yomari Punhi", category: .publicHoliday, rule: .lunar(month: 8, tithi: 15, at: .sunrise)),
        .init(key: "sonamLhosar", ne: "सोनाम ल्होसार", en: "Sonam Lhosar", category: .publicHoliday, rule: .lunar(month: 10, tithi: 1, at: .sunrise)),
        .init(key: "basantaPanchami", ne: "बसन्त पञ्चमी / सरस्वती पूजा", en: "Basanta Panchami / Saraswati Puja", category: .festival, rule: .lunar(month: 10, tithi: 5, at: .sunrise),
              noteNe: "शैक्षिक संस्थामा बिदा", noteEn: "Holiday for schools"),
        .init(key: "shivaratri", ne: "महाशिवरात्रि", en: "Maha Shivaratri", category: .publicHoliday, rule: .lunar(month: 10, tithi: 29, at: .midnight)),
        .init(key: "gyalpoLhosar", ne: "ग्याल्पो ल्होसार", en: "Gyalpo Lhosar", category: .publicHoliday, rule: .lunar(month: 11, tithi: 1, at: .sunrise)),
        .init(key: "holi", ne: "फागु पूर्णिमा (होली)", en: "Fagu Purnima (Holi)", category: .publicHoliday, rule: .lunar(month: 11, tithi: 15, at: .sunset),
              noteNe: "पहाडी र हिमाली जिल्ला", noteEn: "Hill and mountain districts"),
        .init(key: "holiTerai", ne: "होली (तराई)", en: "Holi (Terai)", category: .publicHoliday, rule: .after(key: "holi", days: 1),
              noteNe: "तराईका जिल्ला", noteEn: "Terai districts"),
        .init(key: "ghodeJatra", ne: "घोडेजात्रा", en: "Ghode Jatra", category: .regionalHoliday, rule: .lunar(month: 11, tithi: 30, at: .afternoon),
              noteNe: "काठमाडौं उपत्यकामा बिदा", noteEn: "Holiday in Kathmandu Valley"),

        // Islamic
        .init(key: "eidFitr", ne: "रमजान इद (इद उल फित्र)", en: "Eid al-Fitr", category: .regionalHoliday, rule: .hijri(month: 10, day: 1),
              noteNe: "मुस्लिम समुदायका लागि बिदा, चन्द्रदर्शनअनुसार फरक पर्न सक्छ", noteEn: "Holiday for the Muslim community; may shift with moon sighting"),
        .init(key: "eidAdha", ne: "बकर इद (इद उल अजहा)", en: "Eid al-Adha", category: .regionalHoliday, rule: .hijri(month: 12, day: 10),
              noteNe: "मुस्लिम समुदायका लागि बिदा, चन्द्रदर्शनअनुसार फरक पर्न सक्छ", noteEn: "Holiday for the Muslim community; may shift with moon sighting"),
    ]
}
