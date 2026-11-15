import Foundation
import SambatCore

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
    /// Interface language.
    var language: Language = .english
    /// Dates, months, weekdays, tithi and festival names.
    var calendarLanguage: Language = .nepali
    var basis: DateBasis = .nepal
    var appearance: AppearanceMode = .auto
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
    var eveningHour = 19
    var eveningMinute = 0
    var showCalendarEvents = false
    var checkForUpdates = true

    init() {}

    // Decode field by field so settings saved by older versions keep working.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings()
        func v<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T { (try? c.decode(T.self, forKey: key)) ?? fallback }
        language = v(.language, d.language)
        calendarLanguage = v(.calendarLanguage, d.calendarLanguage)
        basis = v(.basis, d.basis)
        appearance = v(.appearance, d.appearance)
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
        eveningHour = v(.eveningHour, d.eveningHour)
        eveningMinute = v(.eveningMinute, d.eveningMinute)
        showCalendarEvents = v(.showCalendarEvents, d.showCalendarEvents)
        checkForUpdates = v(.checkForUpdates, d.checkForUpdates)

        // 1.0 had colour themes; carry the light/dark choice over to the new appearance setting.
        if !c.contains(.appearance), let legacy = try? decoder.container(keyedBy: LegacyKeys.self),
           let theme = try? legacy.decode(String.self, forKey: .themeID) {
            appearance = ["dark", "midnight", "dhaka"].contains(theme) ? .dark : (theme == "system" ? .auto : .light)
        }
    }

    private enum LegacyKeys: String, CodingKey { case themeID }

    private static let key = "settings.v1"

    static func load() -> AppSettings {
        // Settings saved under the app's previous name carry over on first launch.
        let data = UserDefaults.standard.data(forKey: key)
            ?? UserDefaults(suiteName: "com.officialbishal.nepali-patro")?.data(forKey: key)
        guard let data, let s = try? JSONDecoder().decode(AppSettings.self, from: data) else { return AppSettings() }
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
        s.calendarLanguage = calendarLanguage
        s.basis = basis
        s.appearance = appearance
        s.showTithi = showTithi
        return s
    }
}
