import Foundation
import PatroCore

enum MenuBarFormat: String, Codable, CaseIterable, Identifiable {
    case monthDay, dayMonth, dayMonthWeekday, full, numeric, dayOnly, iconOnly

    var id: String { rawValue }

    func sample(_ bs: BSDate, weekday: Int, _ lang: Language) -> String {
        let month = Formatter.bsMonth(bs.month, lang)
        let day = Formatter.digits(bs.day, lang)
        switch self {
        case .monthDay: return "\(month) \(day)"
        case .dayMonth: return "\(day) \(month)"
        case .dayMonthWeekday: return "\(day) \(month), \(Formatter.weekday(weekday, lang, short: true))"
        case .full: return Formatter.dateLong(bs, lang)
        case .numeric: return Formatter.dateNumeric(bs, lang)
        case .dayOnly: return day
        case .iconOnly: return ""
        }
    }
}

struct AppSettings: Codable, Equatable {
    var language: Language = .nepali
    var basis: DateBasis = .nepal
    var themeID: String = "system"
    var showTithi = true
    var showAD = true
    var menuFormat: MenuBarFormat = .monthDay
    var menuShowsNepalTime = false
    var menuShowsIcon = false
    var notificationsEnabled = false
    var notifyHolidaysOnly = false
    var notifyDayBefore = true
    var notifyHour = 8
    var notifyMinute = 0
    var showCalendarEvents = false
    var checkForUpdates = true

    init() {}

    // Decode field by field so that settings saved by older versions keep working.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings()
        func v<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T { (try? c.decode(T.self, forKey: key)) ?? fallback }
        language = v(.language, d.language)
        basis = v(.basis, d.basis)
        themeID = v(.themeID, d.themeID)
        showTithi = v(.showTithi, d.showTithi)
        showAD = v(.showAD, d.showAD)
        menuFormat = v(.menuFormat, d.menuFormat)
        menuShowsNepalTime = v(.menuShowsNepalTime, d.menuShowsNepalTime)
        menuShowsIcon = v(.menuShowsIcon, d.menuShowsIcon)
        notificationsEnabled = v(.notificationsEnabled, d.notificationsEnabled)
        notifyHolidaysOnly = v(.notifyHolidaysOnly, d.notifyHolidaysOnly)
        notifyDayBefore = v(.notifyDayBefore, d.notifyDayBefore)
        notifyHour = v(.notifyHour, d.notifyHour)
        notifyMinute = v(.notifyMinute, d.notifyMinute)
        showCalendarEvents = v(.showCalendarEvents, d.showCalendarEvents)
        checkForUpdates = v(.checkForUpdates, d.checkForUpdates)
    }

    private static let key = "settings.v1"

    static func load() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: key),
              let s = try? JSONDecoder().decode(AppSettings.self, from: data) else { return AppSettings() }
        return s
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }

    var shared: SharedSettings {
        var s = SharedSettings()
        s.language = language
        s.basis = basis
        s.themeID = themeID
        s.showTithi = showTithi
        return s
    }
}
