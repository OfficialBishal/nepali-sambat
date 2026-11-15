import AppKit
import Observation
import SambatCore
import SambatUI
import WidgetKit

enum Page: String, CaseIterable {
    case calendar, converter, upcoming
}

enum ConvertDirection: String {
    case adToBS, bsToAD
}

@MainActor
@Observable
final class AppModel {
    var settings: AppSettings {
        didSet {
            guard settings != oldValue, !Self.isRendering else { return }
            settings.save()
            settingsChanged(from: oldValue)
        }
    }

    /// Debug renders change settings to draw each configuration. They must never touch the real
    /// saved settings, the widgets' settings file or scheduled notifications.
    nonisolated static var isRenderingProcess: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.environment["PATRO_SNAPSHOT_DIR"] != nil
        #else
        return false
        #endif
    }

    static let isRendering: Bool = {
        #if DEBUG
        return ProcessInfo.processInfo.environment["PATRO_SNAPSHOT_DIR"] != nil
        #else
        return false
        #endif
    }()

    var now = AppModel.currentDate()
    var page: Page = .calendar
    var displayYear: Int
    var displayMonth: Int
    var selectedJDN: Int?
    /// Month navigation direction, for the slide transition.
    var monthStep = 0
    var panelVisible = false {
        didSet { scheduleTick() }
    }

    // Converter state lives here so it survives closing the popover.
    var convertDirection: ConvertDirection = .adToBS
    var convertAD = AppModel.currentDate()
    var convertBS: BSDate

    /// Set by the app delegate; opens the Settings window on a given tab.
    @ObservationIgnored var openSettings: (SettingsTab) -> Void = { _ in }
    @ObservationIgnored var closePopover: () -> Void = {}

    let calendarService = CalendarService()
    let updateChecker = UpdateChecker()

    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var lastTodayJDN: Int = 0

    init() {
        let s = AppSettings.load()
        settings = s
        let today = BSDate(jdn: JDN.of(AppModel.currentDate(), in: s.basis.timeZone)) ?? BSDate(year: 2083, month: 1, day: 1)
        displayYear = today.year
        displayMonth = today.month
        convertBS = today
        lastTodayJDN = JDN.of(AppModel.currentDate(), in: s.basis.timeZone)
        guard !Self.isRendering else { return }
        s.shared.save()
        observeSystem()
        scheduleTick()
        NotificationService.shared.reschedule(settings: s)
        if s.checkForUpdates { updateChecker.checkIfDue() }
        if s.showCalendarEvents { calendarService.refreshAuthorization() }
    }

    // MARK: Derived

    /// Interface language.
    var lang: Language { settings.language }
    /// Calendar language: BS dates, weekdays, tithi and festival names.
    var cal: Language { settings.calendarLanguage }
    var todayJDN: Int { JDN.of(now, in: settings.basis.timeZone) }
    var nepalTodayJDN: Int { JDN.of(now, in: NepalTime.timeZone) }
    var localTodayJDN: Int { JDN.of(now, in: .current) }
    var today: BSDate { BSDate(jdn: todayJDN) ?? BSDate(year: 2083, month: 1, day: 1) }
    var focusJDN: Int { selectedJDN ?? todayJDN }

    var palette: Palette { Palette(settings.accent) }

    func t(_ en: String, _ ne: String) -> String { lang == .nepali ? ne : en }

    // One format per kind of value, used on every screen.

    /// BS date with weekday first, in the calendar language: "Monday, 30 Kartik 2083".
    func bsLong(_ jdn: Int, year: Bool = true) -> String {
        guard let bs = BSDate(jdn: jdn) else { return "" }
        return Formatter.dateFull(bs, weekday: JDN.weekday(jdn), cal, year: year)
    }

    /// When a tithi ends, in Nepal time, naming the day when it isn't the day shown: "until Tue 2:16 AM".
    func tithiEnd(_ p: DayPanchang) -> String {
        let endDay = JDN.of(p.tithiEnds, in: NepalTime.timeZone)
        let time = clock(p.tithiEnds)
        let day = endDay == p.jdn ? "" : Formatter.weekday(JDN.weekday(endDay), lang, short: true) + " "
        return t("until \(day)\(time)", "\(day)\(time) सम्म")
    }

    /// How far a day is from today. Near today, when Nepal and this Mac are on different dates, it
    /// names both places: "Today here, yesterday in Nepal".
    func relative(_ jdn: Int) -> String {
        let nepal = nepalTodayJDN, local = localTodayJDN
        guard nepal != local, min(abs(jdn - nepal), abs(jdn - local)) <= 1 else {
            return Formatter.relativeDays(jdn - todayJDN, lang)
        }
        let here = Formatter.relativeDays(jdn - local, lang)
        let there = Formatter.relativeDays(jdn - nepal, lang)
        return t("\(here) here, \(there.prefix(1).lowercased() + there.dropFirst()) in Nepal", "यहाँ \(here), नेपालमा \(there)")
    }

    /// Gregorian date for list rows: "7 Dec", or "11 Jan 2027" outside the current year.
    func adCompact(_ jdn: Int) -> String {
        let ad = ADDate(jdn: jdn)
        return ad.year == ADDate(jdn: todayJDN).year ? Formatter.adShort(ad, .english) : Formatter.adMedium(ad, .english)
    }

    /// Short BS date in the calendar language: "6 Mangsir".
    func bsShort(_ jdn: Int) -> String {
        guard let bs = BSDate(jdn: jdn) else { return "" }
        return Formatter.dateShort(bs, cal)
    }

    /// Gregorian date, always in English: "16 Nov 2026".
    func adMedium(_ jdn: Int) -> String {
        let ad = ADDate(jdn: jdn)
        return Formatter.adMedium(ad, .english)
    }

    /// A clock time in the interface language.
    func clock(_ date: Date, in tz: TimeZone = NepalTime.timeZone) -> String {
        Formatter.time(date, in: tz, lang)
    }

    /// "Public holiday", "Regional holiday: Kathmandu Valley", or nil for plain festivals.
    func holidayLabel(_ e: CalendarEvent) -> String? {
        switch e.category {
        case .publicHoliday:
            let base = t("Public holiday", "सार्वजनिक बिदा")
            return e.note(lang).map { "\(base), \($0)" } ?? base
        case .regionalHoliday:
            let base = t("Regional holiday", "क्षेत्रीय बिदा")
            return e.note(lang).map { "\(base), \($0)" } ?? base
        default:
            return e.note(lang)
        }
    }

    var menuTitle: String {
        var parts: [String] = []
        let s = settings.menuFormat.sample(today, weekday: JDN.weekday(todayJDN), cal)
        if !s.isEmpty { parts.append(s) }
        if settings.menuShowsNepalTime {
            parts.append(Formatter.time(now, in: NepalTime.timeZone, cal))
        }
        return parts.joined(separator: "  ")
    }

    // MARK: Navigation

    func showMonth(of jdn: Int) {
        guard let bs = BSDate(jdn: jdn) else { return }
        displayYear = bs.year
        displayMonth = bs.month
    }

    func step(months n: Int) {
        let next = BSCalendar.addMonths(n, to: displayYear, month: displayMonth)
        guard BSCalendar.contains(year: next.year) else { return }
        monthStep = n
        displayYear = next.year
        displayMonth = next.month
        clearSelectionOutsideDisplayedMonth()
    }

    func goToToday() {
        selectedJDN = nil
        if let t = BSDate(jdn: todayJDN) {
            monthStep = (t.year * 12 + t.month) - (displayYear * 12 + displayMonth)
        }
        showMonth(of: todayJDN)
    }

    /// A selected day that has scrolled out of view would leave the day panel describing a date
    /// the grid no longer shows, so the selection is dropped.
    func clearSelectionOutsideDisplayedMonth() {
        guard let sel = selectedJDN, let bs = BSDate(jdn: sel) else { return }
        if bs.year != displayYear || bs.month != displayMonth { selectedJDN = nil }
    }

    var isShowingCurrentMonth: Bool {
        today.year == displayYear && today.month == displayMonth
    }

    /// Shows a day's month with that day selected (from lists and the converter).
    func reveal(_ jdn: Int) {
        if let bs = BSDate(jdn: jdn) {
            monthStep = (bs.year * 12 + bs.month) - (displayYear * 12 + displayMonth)
        }
        showMonth(of: jdn)
        selectedJDN = jdn
        page = .calendar
    }

    /// Selects a day (today included); choosing the selected day again clears it.
    func select(_ jdn: Int) {
        selectedJDN = (selectedJDN == jdn) ? nil : jdn
    }

    // MARK: Clock

    /// Ticks once a second while the panel is open (for the Nepal clock) and once a minute otherwise.
    /// Nepal's midnight always lands on a minute boundary, so the menu bar flips right on time.
    func scheduleTick() {
        timer?.invalidate()
        let current = Date()
        let interval: TimeInterval = panelVisible ? 1 : 60
        let next = Date(timeIntervalSince1970: (current.timeIntervalSince1970 / interval).rounded(.down) * interval + interval)
        let t = Timer(fire: next.addingTimeInterval(0.05), interval: 0, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        t.tolerance = panelVisible ? 0.1 : 0.5
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    /// Debug builds can pretend it's another time (PATRO_FAKE_NOW=<unix seconds>) to test the Nepal-midnight flip.
    static let clockOffset: TimeInterval = {
        #if DEBUG
        if let v = ProcessInfo.processInfo.environment["PATRO_FAKE_NOW"], let t = TimeInterval(v) {
            return t - Date().timeIntervalSince1970
        }
        #endif
        return 0
    }()

    static func currentDate() -> Date { Date().addingTimeInterval(clockOffset) }

    func tick() {
        now = Self.currentDate()
        let today = todayJDN
        if today != lastTodayJDN {
            dayChanged(from: lastTodayJDN, to: today)
            lastTodayJDN = today
        }
        scheduleTick()
    }

    private func dayChanged(from old: Int, to new: Int) {
        if let oldBS = BSDate(jdn: old), oldBS.year == displayYear, oldBS.month == displayMonth {
            showMonth(of: new)
        }
        if selectedJDN == new { selectedJDN = nil }
        NotificationService.shared.reschedule(settings: settings)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func observeSystem() {
        let ws = NSWorkspace.shared.notificationCenter
        ws.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        for name in [Notification.Name.NSSystemClockDidChange, .NSSystemTimeZoneDidChange, .NSCalendarDayChanged] {
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.tick() }
            }
        }
    }

    private func settingsChanged(from old: AppSettings) {
        if old.shared != settings.shared {
            settings.shared.save()
            WidgetCenter.shared.reloadAllTimelines()
        }
        if old.basis != settings.basis {
            lastTodayJDN = todayJDN
            goToToday()
        }
        if old.notificationsEnabled != settings.notificationsEnabled
            || old.notifyHolidaysOnly != settings.notifyHolidaysOnly
            || old.notifyDayBefore != settings.notifyDayBefore
            || old.notifyHour != settings.notifyHour
            || old.notifyMinute != settings.notifyMinute
            || old.eveningHour != settings.eveningHour
            || old.eveningMinute != settings.eveningMinute
            || old.language != settings.language
            || old.calendarLanguage != settings.calendarLanguage {
            NotificationService.shared.reschedule(settings: settings)
        }
    }
}
