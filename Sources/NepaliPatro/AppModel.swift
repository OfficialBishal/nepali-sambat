import AppKit
import Observation
import PatroCore
import PatroUI
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
            guard settings != oldValue else { return }
            settings.save()
            settingsChanged(from: oldValue)
        }
    }

    var now = AppModel.currentDate()
    var page: Page = .calendar
    var displayYear: Int
    var displayMonth: Int
    var selectedJDN: Int?
    /// Month navigation direction, for the slide transition.
    var monthStep = 0
    /// Debug snapshots paint the popover material, which can't be captured offscreen.
    var snapshotBackground = false
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
    var palette: Palette { Palette(settings.accent) }
    var todayJDN: Int { JDN.of(now, in: settings.basis.timeZone) }
    var nepalTodayJDN: Int { JDN.of(now, in: NepalTime.timeZone) }
    var localTodayJDN: Int { JDN.of(now, in: .current) }
    var today: BSDate { BSDate(jdn: todayJDN) ?? BSDate(year: 2083, month: 1, day: 1) }
    var focusJDN: Int { selectedJDN ?? todayJDN }

    func t(_ en: String, _ ne: String) -> String { lang == .nepali ? ne : en }

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
    }

    func goToToday() {
        selectedJDN = nil
        if let t = BSDate(jdn: todayJDN) {
            monthStep = (t.year * 12 + t.month) - (displayYear * 12 + displayMonth)
        }
        showMonth(of: todayJDN)
    }

    var isShowingCurrentMonth: Bool {
        today.year == displayYear && today.month == displayMonth
    }

    func select(_ jdn: Int) {
        selectedJDN = (jdn == todayJDN) ? nil : jdn
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
            || old.language != settings.language
            || old.calendarLanguage != settings.calendarLanguage {
            NotificationService.shared.reschedule(settings: settings)
        }
    }
}
