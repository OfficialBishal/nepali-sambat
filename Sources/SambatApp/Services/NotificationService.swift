import Foundation
import SambatCore
@preconcurrency import UserNotifications

@MainActor
final class NotificationService {
    static let shared = NotificationService()
    private let prefix = "sambat.festival."
    private var center: UNUserNotificationCenter? {
        // UNUserNotificationCenter traps when the process is not inside an app bundle (e.g. `swift run`).
        Bundle.main.bundleIdentifier == nil ? nil : UNUserNotificationCenter.current()
    }

    func requestAuthorization() async -> Bool {
        guard let center else { return false }
        return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    func authorizationDenied() async -> Bool {
        guard let center else { return true }
        return await center.notificationSettings().authorizationStatus == .denied
    }

    /// Replaces all pending festival reminders with reminders for the next ~60 days.
    func reschedule(settings: AppSettings) {
        guard let center else { return }
        let prefix = self.prefix
        center.getPendingNotificationRequests { requests in
            let ours = requests.map(\.identifier).filter { $0.hasPrefix(prefix) }
            center.removePendingNotificationRequests(withIdentifiers: ours)
            guard settings.notificationsEnabled else { return }
            Task { @MainActor in self.schedule(settings: settings, center: center) }
        }
    }

    private func schedule(settings: AppSettings, center: UNUserNotificationCenter) {
        let lang = settings.calendarLanguage
        let ui = settings.language
        let today = JDN.of(Date(), in: .current)
        let events = FestivalEngine.shared.events(from: today, to: today + 62).filter { e in
            settings.notifyHolidaysOnly ? e.isPublicHoliday : e.category != .observance
        }
        let byDay = Dictionary(grouping: events, by: \.jdn)
        var count = 0
        for jdn in byDay.keys.sorted() {
            guard count < 60, let dayEvents = byDay[jdn] else { break }
            let names = uniqueNames(dayEvents, lang)
            guard !names.isEmpty, let bs = BSDate(jdn: jdn) else { continue }
            let body = names.joined(separator: ", ")
            let dateLine = "\(Formatter.dateLong(bs, lang)), \(Formatter.adLong(ADDate(jdn: jdn), .english))"

            add(center, id: "\(prefix)\(jdn).day", jdn: jdn, title: names.first!, body: names.count > 1 ? "\(body)\n\(dateLine)" : dateLine,
                hour: settings.notifyHour, minute: settings.notifyMinute)
            count += 1
            if settings.notifyDayBefore, jdn - 1 >= today {
                let title = ui == .nepali ? "भोलि: \(names.first!)" : "Tomorrow: \(names.first!)"
                add(center, id: "\(prefix)\(jdn).before", jdn: jdn - 1, title: title, body: dateLine,
                    hour: settings.eveningHour, minute: settings.eveningMinute)
                count += 1
            }
        }
    }

    private func uniqueNames(_ events: [CalendarEvent], _ lang: Language) -> [String] {
        var seen = Set<String>()
        return events.map { $0.name(lang) }.filter { seen.insert($0).inserted }
    }

    private func add(_ center: UNUserNotificationCenter, id: String, jdn: Int, title: String, body: String, hour: Int, minute: Int) {
        let ad = ADDate(jdn: jdn)
        var comps = DateComponents(year: ad.year, month: ad.month, day: ad.day, hour: hour, minute: minute)
        comps.calendar = Calendar(identifier: .gregorian)
        guard let fire = comps.date, fire > Date() else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    func sendTest(lang: Language) {
        guard let center else { return }
        let content = UNMutableNotificationContent()
        content.title = "Nepali Sambat"
        content.body = lang == .nepali ? "चाडपर्वको सूचना यसरी आउनेछ।" : "Festival reminders will look like this."
        center.add(UNNotificationRequest(identifier: "sambat.test", content: content,
                                         trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)))
    }
}
