import AppKit
import EventKit
import Observation
import SambatCore

/// Apple Calendar integration: show the user's events for a day, and write Nepali festivals into
/// a dedicated "Nepali Festivals" calendar.
@MainActor
@Observable
final class CalendarService {
    @ObservationIgnored private let store = EKEventStore()
    private(set) var status: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)
    private(set) var changeCounter = 0
    var lastSyncMessage: String?

    private let calendarIDKey = "festivalCalendarID"

    init() {
        NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.changeCounter += 1 }
        }
    }

    var hasAccess: Bool { status == .fullAccess }

    /// Whether the Nepali Festivals calendar currently exists in Calendar.
    var hasFestivalCalendar: Bool {
        _ = changeCounter
        guard hasAccess, let id = UserDefaults.standard.string(forKey: calendarIDKey) else { return false }
        return store.calendar(withIdentifier: id) != nil
    }

    func refreshAuthorization() {
        status = EKEventStore.authorizationStatus(for: .event)
    }

    @discardableResult
    func requestAccess() async -> Bool {
        let granted = (try? await store.requestFullAccessToEvents()) ?? false
        status = EKEventStore.authorizationStatus(for: .event)
        return granted
    }

    func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
    }

    /// The user's events on a civil day (in this Mac's time zone), excluding our own festival calendar.
    func events(on ad: ADDate) -> [EKEvent] {
        _ = changeCounter
        guard hasAccess else { return [] }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        guard let start = cal.date(from: DateComponents(year: ad.year, month: ad.month, day: ad.day)),
              let end = cal.date(byAdding: .day, value: 1, to: start) else { return [] }
        let ours = UserDefaults.standard.string(forKey: calendarIDKey)
        let calendars = store.calendars(for: .event).filter { $0.calendarIdentifier != ours }
        guard !calendars.isEmpty else { return [] }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: calendars)
        return store.events(matching: predicate).sorted { a, b in
            if a.isAllDay != b.isAllDay { return a.isAllDay }
            return a.startDate < b.startDate
        }
    }

    private func festivalCalendar(create: Bool) throws -> EKCalendar? {
        if let id = UserDefaults.standard.string(forKey: calendarIDKey), let cal = store.calendar(withIdentifier: id) {
            return cal
        }
        guard create else { return nil }
        let cal = EKCalendar(for: .event, eventStore: store)
        cal.title = "Nepali Festivals"
        cal.cgColor = NSColor(srgbRed: 0.86, green: 0.08, blue: 0.24, alpha: 1).cgColor
        let preferred = store.defaultCalendarForNewEvents?.source
        let local = store.sources.first { $0.sourceType == .local }
        guard let source = preferred ?? local ?? store.sources.first else {
            throw NSError(domain: "Sambat", code: 1, userInfo: [NSLocalizedDescriptionKey: "No calendar account available"])
        }
        cal.source = source
        do {
            try store.saveCalendar(cal, commit: true)
        } catch {
            guard let local, source != local else { throw error }
            cal.source = local
            try store.saveCalendar(cal, commit: true)
        }
        UserDefaults.standard.set(cal.calendarIdentifier, forKey: calendarIDKey)
        return cal
    }

    /// Writes festivals for the current and next BS year (holidays and festivals; observances skipped).
    func syncFestivals(lang: Language) async -> String {
        if !hasAccess { _ = await requestAccess() }
        guard hasAccess else { return lang == .nepali ? "क्यालेन्डर अनुमति छैन" : "Calendar access was not granted" }
        do {
            guard let cal = try festivalCalendar(create: true),
                  let year = NepalTime.today()?.year,
                  let from = BSCalendar.startJDN(year: year) else { return "" }
            let to = (BSCalendar.startJDN(year: year + 2) ?? from + 730)
            let startDate = JDN.startOfDay(from, in: .current)
            let endDate = JDN.startOfDay(to, in: .current)
            let existing = store.events(matching: store.predicateForEvents(withStart: startDate, end: endDate, calendars: [cal]))
            for e in existing { try store.remove(e, span: .thisEvent, commit: false) }

            let events = FestivalEngine.shared.events(from: from, to: to).filter { $0.category != .observance }
            var byDay: [Int: [CalendarEvent]] = [:]
            for e in events { byDay[e.jdn, default: []].append(e) }
            for (jdn, dayEvents) in byDay {
                var seen = Set<String>()
                for e in dayEvents where seen.insert(e.nameEn).inserted {
                    let ev = EKEvent(eventStore: store)
                    ev.calendar = cal
                    ev.title = lang == .nepali ? e.nameNe : e.nameEn
                    ev.isAllDay = true
                    ev.startDate = JDN.startOfDay(jdn, in: .current)
                    ev.endDate = ev.startDate
                    let bs = BSDate(jdn: jdn).map { Formatter.dateLong($0, .nepali) } ?? ""
                    var notes = "\(e.nameNe)\n\(e.nameEn)\n\(bs)"
                    if e.isPublicHoliday { notes += "\nसार्वजनिक बिदा (public holiday)" }
                    if let n = e.noteEn { notes += "\n\(n)" }
                    ev.notes = notes
                    try store.save(ev, span: .thisEvent, commit: false)
                }
            }
            try store.commit()
            let n = byDay.values.reduce(0) { $0 + $1.count }
            return lang == .nepali ? "\(Formatter.digits(n, .nepali)) चाडपर्व क्यालेन्डरमा थपियो" : "Added \(n) festivals to Calendar"
        } catch {
            return error.localizedDescription
        }
    }

    func removeFestivalCalendar(lang: Language) -> String {
        do {
            if let cal = try festivalCalendar(create: false) {
                try store.removeCalendar(cal, commit: true)
            }
            UserDefaults.standard.removeObject(forKey: calendarIDKey)
            return lang == .nepali ? "चाडपर्व क्यालेन्डर हटाइयो" : "Removed the Nepali Festivals calendar"
        } catch {
            return error.localizedDescription
        }
    }
}
