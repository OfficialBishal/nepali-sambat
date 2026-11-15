import PatroCore
import PatroUI
import SwiftUI

struct NotificationSettings: View {
    @Environment(AppModel.self) private var model
    private var _denied = State<Bool>(initialValue: false)
    private var denied: Bool { get { _denied.wrappedValue } nonmutating set { _denied.wrappedValue = newValue } }

    var body: some View {
        @Bindable var model = model
        Card {
            SectionLabel(text: model.t("Festival reminders", "चाडपर्व सूचना"))
            SettingRow(title: model.t("Remind me about festivals", "चाडपर्वको सूचना दिनुहोस्"),
                       caption: denied ? model.t("Notifications are turned off in System Settings.", "सिस्टम सेटिङमा सूचना बन्द छ।") : nil) {
                Toggle("", isOn: Binding(
                    get: { model.settings.notificationsEnabled },
                    set: { on in
                        if on {
                            Task {
                                let ok = await NotificationService.shared.requestAuthorization()
                                denied = !ok
                                model.settings.notificationsEnabled = ok
                            }
                        } else {
                            model.settings.notificationsEnabled = false
                        }
                    }
                )).labelsHidden()
            }
            if model.settings.notificationsEnabled {
                SettingRow(title: model.t("On the day at", "सोही दिन")) {
                    DatePicker("", selection: reminderTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .datePickerStyle(.stepperField)
                        .fixedSize()
                }
                SettingRow(title: model.t("Also the evening before (7 PM)", "अघिल्लो साँझ पनि (७ बजे)")) {
                    Toggle("", isOn: $model.settings.notifyDayBefore).labelsHidden()
                }
                SettingRow(title: model.t("Public holidays only", "सार्वजनिक बिदा मात्र")) {
                    Toggle("", isOn: $model.settings.notifyHolidaysOnly).labelsHidden()
                }
                HStack {
                    Spacer()
                    PillButton(title: model.t("Send a test", "परीक्षण सूचना"), systemImage: "bell") {
                        NotificationService.shared.sendTest(lang: model.lang)
                    }
                }
            }
        }
        .task { denied = model.settings.notificationsEnabled ? await NotificationService.shared.authorizationDenied() : false }
    }

    private var reminderTime: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: model.settings.notifyHour, minute: model.settings.notifyMinute, second: 0, of: Date()) ?? Date()
            },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                model.settings.notifyHour = c.hour ?? 8
                model.settings.notifyMinute = c.minute ?? 0
            }
        )
    }
}

struct CalendarSettings: View {
    @Environment(AppModel.self) private var model
    private var _working = State<Bool>(initialValue: false)
    private var working: Bool { get { _working.wrappedValue } nonmutating set { _working.wrappedValue = newValue } }
    private var _message = State<String?>(initialValue: nil)
    private var message: String? { get { _message.wrappedValue } nonmutating set { _message.wrappedValue = newValue } }

    var body: some View {
        let service = model.calendarService
        Card {
            SectionLabel(text: model.t("Apple Calendar", "एप्पल क्यालेन्डर"))
            SettingRow(title: model.t("Show my events", "मेरा कार्यक्रम देखाउनुहोस्"),
                       caption: model.t("Your Calendar events appear under the selected day.", "छानिएको दिनमुनि तपाईंका कार्यक्रम देखिन्छन्।")) {
                Toggle("", isOn: Binding(
                    get: { model.settings.showCalendarEvents && service.hasAccess },
                    set: { on in
                        if on {
                            Task {
                                let ok = await service.requestAccess()
                                model.settings.showCalendarEvents = ok
                                if !ok { message = model.t("Allow access in System Settings › Privacy › Calendars.", "सिस्टम सेटिङ › गोपनीयता › क्यालेन्डरमा अनुमति दिनुहोस्।") }
                            }
                        } else {
                            model.settings.showCalendarEvents = false
                        }
                    }
                )).labelsHidden()
            }
            HStack(spacing: 6) {
                PillButton(title: model.t("Add festivals", "चाडपर्व थप्नुहोस्"), systemImage: "calendar.badge.plus", prominent: true) {
                    working = true
                    Task {
                        message = await service.syncFestivals(lang: model.lang)
                        working = false
                    }
                }
                PillButton(title: model.t("Remove", "हटाउनुहोस्"), systemImage: "trash") {
                    message = service.removeFestivalCalendar(lang: model.lang)
                }
                PillButton(title: ".ics", systemImage: "square.and.arrow.down") {
                    ICSExport.run(lang: model.lang)
                }
                if working { ProgressView().controlSize(.mini) }
            }
            if let message {
                Text(message).font(.system(size: 10)).foregroundStyle(model.theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(model.t("Creates a “Nepali Festivals” calendar with this year's and next year's holidays.",
                             "यो र अर्को वर्षका बिदासहित “Nepali Festivals” क्यालेन्डर बनाउँछ।"))
                    .font(.system(size: 10)).foregroundStyle(model.theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct GeneralSettings: View {
    @Environment(AppModel.self) private var model
    private var _launchAtLogin = State<Bool>(initialValue: LaunchAtLogin.isEnabled)
    private var launchAtLogin: Bool { get { _launchAtLogin.wrappedValue } nonmutating set { _launchAtLogin.wrappedValue = newValue } }
    private var _copiedBrew = State<Bool>(initialValue: false)
    private var copiedBrew: Bool { get { _copiedBrew.wrappedValue } nonmutating set { _copiedBrew.wrappedValue = newValue } }

    var body: some View {
        @Bindable var model = model
        let updater = model.updateChecker
        let theme = model.theme
        Card {
            SectionLabel(text: model.t("General", "सामान्य"))
            SettingRow(title: model.t("Open at login", "लगइनमा खोल्नुहोस्")) {
                Toggle("", isOn: Binding(
                    get: { launchAtLogin },
                    set: { on in
                        _ = LaunchAtLogin.set(on)
                        launchAtLogin = LaunchAtLogin.isEnabled
                    }
                )).labelsHidden()
            }
            SettingRow(title: model.t("Check for updates daily", "दैनिक अपडेट जाँच")) {
                Toggle("", isOn: $model.settings.checkForUpdates).labelsHidden()
            }
            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: "Nepali Patro \(AppInfo.version)").font(.system(size: 12, weight: .semibold))
                    if updater.updateAvailable, let v = updater.latestVersion {
                        Text(model.t("Version \(v) is available", "संस्करण \(v) उपलब्ध छ"))
                            .font(.system(size: 10, weight: .medium)).foregroundStyle(theme.accent)
                    } else if updater.latestVersion != nil {
                        Text(model.t("You're up to date", "नयाँ संस्करण नै छ")).font(.system(size: 10)).foregroundStyle(theme.secondary)
                    }
                }
                Spacer()
                if updater.checking {
                    ProgressView().controlSize(.mini)
                } else {
                    PillButton(title: model.t("Check", "जाँच"), systemImage: "arrow.clockwise") {
                        Task { await updater.check() }
                    }
                }
            }
            if updater.updateAvailable {
                HStack(spacing: 6) {
                    PillButton(title: copiedBrew ? model.t("Copied", "कपी भयो") : "brew upgrade", systemImage: "terminal", prominent: true) {
                        Clipboard.copy("brew upgrade --cask \(AppInfo.caskName)")
                        copiedBrew = true
                    }
                    PillButton(title: model.t("Download", "डाउनलोड"), systemImage: "arrow.down.circle") {
                        NSWorkspace.shared.open(AppInfo.releasesURL)
                    }
                }
            }
            HStack(spacing: 6) {
                PillButton(title: "GitHub", systemImage: "chevron.left.forwardslash.chevron.right") {
                    NSWorkspace.shared.open(AppInfo.repoURL)
                }
                PillButton(title: model.t("Report a problem", "समस्या रिपोर्ट"), systemImage: "exclamationmark.bubble") {
                    NSWorkspace.shared.open(AppInfo.issuesURL)
                }
            }
            Text(model.t("Holidays are computed from astronomy and the Nepali patro rules, and checked against the Government of Nepal's lists. Moon-sighted holidays (Eid) may shift by a day.",
                         "बिदाहरू खगोलीय गणना र पात्रोका नियमअनुसार निकालिएका हुन् र नेपाल सरकारको सूचीसँग जाँचिएका छन्। चन्द्रदर्शनमा आधारित बिदा (इद) एक दिन फरक पर्न सक्छ।"))
                .font(.system(size: 9.5))
                .foregroundStyle(theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
