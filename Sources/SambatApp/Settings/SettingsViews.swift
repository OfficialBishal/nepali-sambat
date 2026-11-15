import SambatCore
import SambatUI
import SwiftUI

struct GeneralSettings: View {
    @Environment(AppModel.self) private var model
    private var _launchAtLogin = State<Bool>(initialValue: LaunchAtLogin.isEnabled)
    private var launchAtLogin: Bool { get { _launchAtLogin.wrappedValue } nonmutating set { _launchAtLogin.wrappedValue = newValue } }
    private var _copiedBrew = State<Bool>(initialValue: false)
    private var copiedBrew: Bool { get { _copiedBrew.wrappedValue } nonmutating set { _copiedBrew.wrappedValue = newValue } }

    var body: some View {
        @Bindable var model = model
        let updater = model.updateChecker
        Form {
            Section {
                Picker(model.t("New day starts at", "नयाँ दिन सुरु हुने"), selection: $model.settings.basis) {
                    Text(model.t("Midnight in Nepal", "नेपालको मध्यरातमा")).tag(DateBasis.nepal)
                    Text(model.t("Midnight here", "यहाँको मध्यरातमा")).tag(DateBasis.local)
                }
            } footer: {
                Text(basisFooter).foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Section {
                Picker(model.t("App language", "एपको भाषा"), selection: $model.settings.language) {
                    Text("English").tag(Language.english)
                    Text("नेपाली").tag(Language.nepali)
                }
                Picker(model.t("Dates in", "मितिको भाषा"), selection: $model.settings.calendarLanguage) {
                    Text(verbatim: "नेपाली (\(sample(.nepali)))").tag(Language.nepali)
                    Text(verbatim: "English (\(sample(.english)))").tag(Language.english)
                }
            } header: {
                Text(model.t("Language", "भाषा"))
            } footer: {
                Text(model.t("Nepali dates, weekdays, tithi and festival names use this language. AD dates are always in English.",
                             "नेपाली मिति, बार, तिथि र चाडपर्वका नाम यही भाषामा देखिन्छन्। ईस्वी मिति सधैं अंग्रेजीमा।"))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Section {
                Toggle(model.t("Open at login", "लगइन गर्दा खोल्नुहोस्"), isOn: Binding(
                    get: { launchAtLogin },
                    set: { _ = LaunchAtLogin.set($0); launchAtLogin = LaunchAtLogin.isEnabled }
                ))
                Toggle(model.t("Check for updates automatically", "अपडेट आफैं जाँच गर्नुहोस्"), isOn: $model.settings.checkForUpdates)
                LabeledContent(model.t("Version", "संस्करण")) {
                    HStack(spacing: 8) {
                        Text(versionText(updater)).foregroundStyle(.secondary)
                        if updater.checking {
                            ProgressView().controlSize(.small)
                        } else if updater.updateAvailable {
                            Button(copiedBrew ? model.t("Copied", "कपी भयो") : model.t("Copy brew command", "brew कमाण्ड कपी")) {
                                Clipboard.copy("brew upgrade --cask \(AppInfo.caskName)")
                                copiedBrew = true
                            }
                            .help("brew upgrade --cask \(AppInfo.caskName)")
                            Button(model.t("Download", "डाउनलोड")) { NSWorkspace.shared.open(AppInfo.releasesURL) }
                        } else {
                            Button(model.t("Check Now", "अहिले जाँच्नुहोस्")) { Task { await updater.check() } }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func sample(_ lang: Language) -> String {
        "\(Formatter.bsMonth(model.today.month, lang)) \(Formatter.digits(model.today.day, lang))"
    }

    private var basisFooter: String {
        switch model.settings.basis {
        case .nepal:
            let flip = NepalTime.nextDayChange(after: model.now, basis: .nepal)
            let here = Formatter.time(flip, in: .current, model.lang)
            if NepalTime.offsetSeconds(from: .current, at: model.now) == 0 {
                return model.t("The Nepali date changes at midnight in Nepal.", "नेपालको मध्यरातमा मिति फेरिन्छ।")
            }
            return model.t("The Nepali date changes at midnight in Nepal, which is \(here) here.",
                           "नेपालको मध्यरातमा मिति फेरिन्छ, अर्थात् यहाँको \(here) मा।")
        case .local:
            return model.t("The Nepali date changes at midnight where you are.", "तपाईं भएको ठाउँको मध्यरातमा मिति फेरिन्छ।")
        }
    }

    private func versionText(_ updater: UpdateChecker) -> String {
        if updater.updateAvailable, let v = updater.latestVersion {
            return model.t("\(AppInfo.version), \(v) available", "\(AppInfo.version), \(v) उपलब्ध")
        }
        return AppInfo.version
    }
}

struct MenuBarSettings: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        let today = model.today
        let wd = JDN.weekday(model.todayJDN)
        Form {
            Section {
                MenuBarPreview(title: model.menuTitle, iconOnly: model.settings.menuFormat == .iconOnly,
                               symbol: model.settings.menuShowsIcon, day: Formatter.digits(today.day, model.cal))
                    .listRowInsets(EdgeInsets())
                Picker(model.t("Format", "ढाँचा"), selection: $model.settings.menuFormat) {
                    ForEach(MenuBarFormat.allCases) { f in
                        Text(f == .iconOnly ? model.t("Calendar icon only", "क्यालेन्डर आइकन मात्र")
                                            : f.sample(today, weekday: wd, model.cal)).tag(f)
                    }
                }
                Toggle(model.t("Show the time in Nepal", "नेपालको समय देखाउनुहोस्"), isOn: $model.settings.menuShowsNepalTime)
                Toggle(model.t("Show a calendar icon", "क्यालेन्डर आइकन देखाउनुहोस्"), isOn: $model.settings.menuShowsIcon)
                    .disabled(model.settings.menuFormat == .iconOnly)
            }
        }
        .formStyle(.grouped)
    }
}

/// The status item as it will look, on a strip of menu bar in both appearances.
struct MenuBarPreview: View {
    let title: String
    let iconOnly: Bool
    let symbol: Bool
    let day: String

    var body: some View {
        HStack(spacing: 0) {
            strip(dark: false)
            strip(dark: true)
        }
        .frame(height: 30)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title.isEmpty ? day : title)
    }

    private func strip(dark: Bool) -> some View {
        HStack(spacing: 4) {
            Spacer(minLength: 0)
            if iconOnly {
                Image(nsImage: MenuBarIcon.calendar(day: day))
            } else if symbol {
                Image(systemName: "calendar")
            }
            if !title.isEmpty {
                Text(title).font(Font(NSFont.menuBarFont(ofSize: 0)))
            }
            Image(systemName: "wifi").padding(.leading, 10)
            Image(systemName: "battery.75percent")
            Spacer(minLength: 0)
        }
        .foregroundStyle(dark ? Color.white : Color.black)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(dark ? Color(white: 0.16) : Color(white: 0.93))
    }
}

struct AppearanceSettings: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Form {
            Section {
                Picker(model.t("Mode", "मोड"), selection: $model.settings.appearance) {
                    Text(model.t("Auto", "स्वचालित")).tag(AppearanceMode.auto)
                    Text(model.t("Light", "उज्यालो")).tag(AppearanceMode.light)
                    Text(model.t("Dark", "अँध्यारो")).tag(AppearanceMode.dark)
                }
                .pickerStyle(.segmented)
                LabeledContent(model.t("Accent color", "मुख्य रङ")) {
                    AccentPicker(selection: $model.settings.accent, lang: model.lang)
                }
            } footer: {
                Text(model.t("The accent colour marks today and the selected day. Holidays and Saturdays are always red, as in a printed Nepali calendar.",
                             "मुख्य रङले आज र छानिएको दिन देखाउँछ। छापिएको पात्रोमा जस्तै बिदा र शनिबार सधैं रातो।"))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Section(model.t("Month view", "महिना")) {
                Toggle(model.t("Show tithi under each day", "हरेक दिनमुनि तिथि देखाउनुहोस्"), isOn: $model.settings.showTithi)
                Toggle(model.t("Show AD dates", "ईस्वी मिति देखाउनुहोस्"), isOn: $model.settings.showAD)
            }
        }
        .formStyle(.grouped)
    }
}

/// A row of colour swatches like the accent picker in System Settings.
struct AccentPicker: View {
    @Binding var selection: AccentChoice
    let lang: Language

    var body: some View {
        HStack(spacing: 7) {
            ForEach(AccentChoice.allCases, id: \.self) { choice in
                Button { selection = choice } label: {
                    ZStack {
                        if choice == .system {
                            Circle().fill(AngularGradient(colors: [.red, .orange, .yellow, .green, .teal, .blue, .purple, .pink, .red],
                                                          center: .center))
                        } else {
                            Circle().fill(Palette(choice).accent)
                        }
                        Circle().strokeBorder(Color.primary.opacity(0.15), lineWidth: 0.5)
                        if selection == choice {
                            Circle().fill(Color.white).frame(width: 5, height: 5)
                        }
                    }
                    .frame(width: 16, height: 16)
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help(Palette.name(choice, lang))
                .accessibilityLabel(Palette.name(choice, lang))
                .accessibilityAddTraits(selection == choice ? .isSelected : [])
            }
        }
    }
}

struct ReminderSettings: View {
    @Environment(AppModel.self) private var model
    private var _denied = State<Bool>(initialValue: false)
    private var denied: Bool { get { _denied.wrappedValue } nonmutating set { _denied.wrappedValue = newValue } }

    var body: some View {
        @Bindable var model = model
        Form {
            Section {
                Toggle(model.t("Remind me about festivals", "चाडपर्वको सूचना दिनुहोस्"), isOn: Binding(
                    get: { model.settings.notificationsEnabled },
                    set: { on in
                        guard on else { model.settings.notificationsEnabled = false; return }
                        Task {
                            let ok = await NotificationService.shared.requestAuthorization()
                            denied = !ok
                            model.settings.notificationsEnabled = ok
                        }
                    }
                ))
                if model.settings.notificationsEnabled {
                    DatePicker(model.t("On the day, at", "सोही दिन, समय"), selection: time(\.notifyHour, \.notifyMinute),
                               displayedComponents: .hourAndMinute)
                    Toggle(model.t("Also the evening before", "अघिल्लो साँझ पनि"), isOn: $model.settings.notifyDayBefore)
                    if model.settings.notifyDayBefore {
                        DatePicker(model.t("Evening before, at", "अघिल्लो साँझ, समय"), selection: time(\.eveningHour, \.eveningMinute),
                                   displayedComponents: .hourAndMinute)
                    }
                    Toggle(model.t("Public holidays only", "सार्वजनिक बिदा मात्र"), isOn: $model.settings.notifyHolidaysOnly)
                }
            } footer: {
                if denied {
                    HStack(spacing: 6) {
                        Text(model.t("Notifications are off for Nepali Sambat in System Settings.", "सिस्टम सेटिङमा Nepali Sambat को सूचना बन्द छ।"))
                        Button(model.t("Open System Settings", "सिस्टम सेटिङ खोल्नुहोस्")) {
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")!)
                        }
                        .buttonStyle(.link)
                    }
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else if model.settings.notificationsEnabled {
                    Button(model.t("Send a Test Notification", "परीक्षण सूचना पठाउनुहोस्")) {
                        NotificationService.shared.sendTest(lang: model.lang)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(model.t("Get a notification on festival days at a time you choose, and the evening before if you like.",
                                 "चाडपर्वको दिन आफूले रोजेको समयमा, र चाहे अघिल्लो साँझ पनि सूचना पाउनुहोस्।"))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .formStyle(.grouped)
        .task { denied = model.settings.notificationsEnabled ? await NotificationService.shared.authorizationDenied() : false }
    }

    private func time(_ hour: WritableKeyPath<AppSettings, Int>, _ minute: WritableKeyPath<AppSettings, Int>) -> Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: model.settings[keyPath: hour], minute: model.settings[keyPath: minute],
                                      second: 0, of: Date()) ?? Date()
            },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                model.settings[keyPath: hour] = c.hour ?? 8
                model.settings[keyPath: minute] = c.minute ?? 0
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
    private var _copiedFeed = State<Bool>(initialValue: false)
    private var copiedFeed: Bool { get { _copiedFeed.wrappedValue } nonmutating set { _copiedFeed.wrappedValue = newValue } }

    var body: some View {
        let service = model.calendarService
        Form {
            Section {
                Toggle(model.t("Show my events in Nepali Sambat", "मेरा कार्यक्रम Nepali Sambat मा देखाउनुहोस्"), isOn: Binding(
                    get: { model.settings.showCalendarEvents && service.hasAccess },
                    set: { on in
                        guard on else { model.settings.showCalendarEvents = false; return }
                        Task {
                            let ok = await service.requestAccess()
                            model.settings.showCalendarEvents = ok
                            if !ok {
                                message = model.t("Allow access in System Settings, Privacy & Security, Calendars.",
                                                  "सिस्टम सेटिङ, गोपनीयता र सुरक्षा, क्यालेन्डरमा अनुमति दिनुहोस्।")
                            }
                        }
                    }
                ))
            } footer: {
                Text(model.t("Events from your calendars appear when you select a day in the month.", "महिनामा दिन छान्दा तपाईंका क्यालेन्डरका कार्यक्रम देखिन्छन्।"))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Section {
                LabeledContent {
                    HStack(spacing: 8) {
                        if working { ProgressView().controlSize(.small) }
                        Button(service.hasFestivalCalendar ? model.t("Update", "अपडेट") : model.t("Add", "थप्नुहोस्")) {
                            working = true
                            Task {
                                message = await service.syncFestivals(lang: model.cal)
                                working = false
                            }
                        }
                        if service.hasFestivalCalendar {
                            Button(model.t("Remove", "हटाउनुहोस्")) { message = service.removeFestivalCalendar(lang: model.lang) }
                        }
                    }
                } label: {
                    Text(model.t("Nepali Festivals calendar", "Nepali Festivals क्यालेन्डर"))
                    Text(service.hasFestivalCalendar ? model.t("Added to Calendar", "क्यालेन्डरमा थपिएको") : model.t("Not added", "थपिएको छैन"))
                }
                LabeledContent(model.t("Export a file", "फाइल निर्यात")) {
                    Button(model.t("Save .ics…", ".ics सेभ…")) { ICSExport.run(lang: model.cal) }
                }
                LabeledContent {
                    Button(copiedFeed ? model.t("Copied", "कपी भयो") : model.t("Copy Link", "लिङ्क कपी")) {
                        Clipboard.copy(AppInfo.feedURL(model.cal))
                        copiedFeed = true
                    }
                    .help(AppInfo.feedURL(model.cal))
                } label: {
                    Text(model.t("Subscribe in other apps", "अन्य एपमा सब्सक्राइब"))
                    Text(model.t("Google Calendar, Outlook and others", "गुगल क्यालेन्डर, आउटलुक आदि"))
                }
            } footer: {
                Text(message ?? model.t("The calendar holds this year’s and next year’s festivals. A subscription link stays up to date by itself.",
                                        "क्यालेन्डरमा यो र अर्को वर्षका चाडपर्व हुन्छन्। सब्सक्राइब लिङ्क आफैं अपडेट हुन्छ।"))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .formStyle(.grouped)
    }
}

struct AboutSettings: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 88, height: 88)
            Text("Nepali Sambat")
                .font(.title2.weight(.semibold))
            Text(model.t("Version \(AppInfo.version) (\(AppInfo.build))", "संस्करण \(AppInfo.version) (\(AppInfo.build))"))
                .font(.callout)
                .foregroundStyle(.secondary)
            Text(model.t("A Nepali calendar for the menu bar that follows Nepal time.",
                         "नेपालको समयअनुसार चल्ने मेनु बारको नेपाली पात्रो।"))
                .font(.callout)
                .padding(.top, 4)
            Text(model.t("Tithi and festivals are computed on this Mac from the positions of the Sun and Moon, and checked against the Government of Nepal’s holiday lists. Eid follows moon sighting and can move by a day.",
                         "तिथि र चाडपर्व सूर्य र चन्द्रमाको स्थितिबाट यही म्याकमा गणना गरिन्छन् र नेपाल सरकारको बिदा सूचीसँग जाँचिएका छन्। इद चन्द्रदर्शनअनुसार एक दिन फरक पर्न सक्छ।"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                Button(model.t("Source Code", "सोर्स कोड")) { NSWorkspace.shared.open(AppInfo.repoURL) }
                Button(model.t("Report a Problem", "समस्या रिपोर्ट गर्नुहोस्")) { NSWorkspace.shared.open(AppInfo.issuesURL) }
            }
            .padding(.top, 6)
            Text("© 2026 Bishal Shrestha. MIT License.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
