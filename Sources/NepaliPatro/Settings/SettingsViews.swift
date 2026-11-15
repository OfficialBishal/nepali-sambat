import PatroCore
import PatroUI
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
                Picker(model.t("Today follows", "आजको मिति"), selection: $model.settings.basis) {
                    Text(model.t("Nepal time", "नेपालको समयअनुसार")).tag(DateBasis.nepal)
                    Text(model.t("This Mac’s time", "यो म्याकको समयअनुसार")).tag(DateBasis.local)
                }
            } footer: {
                Text(basisFooter).foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Section {
                Picker(model.t("Interface", "इन्टरफेस"), selection: $model.settings.language) {
                    Text("English").tag(Language.english)
                    Text("नेपाली").tag(Language.nepali)
                }
                Picker(model.t("Calendar", "पात्रो"), selection: $model.settings.calendarLanguage) {
                    Text(verbatim: "नेपाली  (\(sample(.nepali)))").tag(Language.nepali)
                    Text(verbatim: "English  (\(sample(.english)))").tag(Language.english)
                }
            } header: {
                Text(model.t("Language", "भाषा"))
            } footer: {
                Text(model.t("The calendar language is used for dates, weekdays, tithi and festival names.",
                             "मिति, बार, तिथि र चाडपर्वका नाम पात्रोको भाषामा देखिन्छन्।"))
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
        Formatter.dateLong(model.today, lang)
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
                LabeledContent(model.t("Preview", "नमुना")) {
                    MenuBarPreview(title: model.menuTitle, iconOnly: model.settings.menuFormat == .iconOnly,
                                   symbol: model.settings.menuShowsIcon, day: Formatter.digits(today.day, model.cal))
                }
                Picker(model.t("Show", "देखाउने"), selection: $model.settings.menuFormat) {
                    ForEach(MenuBarFormat.allCases) { f in
                        Text(f == .iconOnly ? model.t("Calendar icon only", "क्यालेन्डर आइकन मात्र")
                                            : f.sample(today, weekday: wd, model.cal)).tag(f)
                    }
                }
                Toggle(model.t("Show the time in Nepal", "नेपालको समय देखाउनुहोस्"), isOn: $model.settings.menuShowsNepalTime)
                Toggle(model.t("Show a calendar symbol", "क्यालेन्डर चिन्ह देखाउनुहोस्"), isOn: $model.settings.menuShowsIcon)
                    .disabled(model.settings.menuFormat == .iconOnly)
            }
        }
        .formStyle(.grouped)
    }
}

/// How the status item will look, drawn with the menu bar font.
struct MenuBarPreview: View {
    let title: String
    let iconOnly: Bool
    let symbol: Bool
    let day: String

    var body: some View {
        HStack(spacing: 4) {
            if iconOnly {
                Image(nsImage: MenuBarIcon.calendar(day: day))
            } else if symbol {
                Image(systemName: "calendar")
            }
            if !title.isEmpty {
                Text(title).font(Font(NSFont.menuBarFont(ofSize: 0)))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Color.primary.opacity(0.07)))
    }
}

struct AppearanceSettings: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Form {
            Section {
                Picker(model.t("Appearance", "रूप"), selection: $model.settings.appearance) {
                    Text(model.t("Auto", "स्वचालित")).tag(AppearanceMode.auto)
                    Text(model.t("Light", "उज्यालो")).tag(AppearanceMode.light)
                    Text(model.t("Dark", "अँध्यारो")).tag(AppearanceMode.dark)
                }
                .pickerStyle(.segmented)
                LabeledContent(model.t("Accent color", "मुख्य रङ")) {
                    AccentPicker(selection: $model.settings.accent, lang: model.lang)
                }
            } footer: {
                Text(model.t("Holidays and Saturdays are always red, as in a printed patro.",
                             "छापिएको पात्रोमा जस्तै बिदा र शनिबार सधैं रातो देखिन्छन्।"))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Section(model.t("Calendar", "पात्रो")) {
                Toggle(model.t("Show tithi under each day", "हरेक दिनमुनि तिथि देखाउनुहोस्"), isOn: $model.settings.showTithi)
                Toggle(model.t("Show English dates", "अंग्रेजी मिति देखाउनुहोस्"), isOn: $model.settings.showAD)
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
            } footer: {
                if denied {
                    HStack(spacing: 6) {
                        Text(model.t("Notifications are turned off for Nepali Patro.", "नेपाली पात्रोको सूचना बन्द छ।"))
                        Button(model.t("Open System Settings", "सिस्टम सेटिङ खोल्नुहोस्")) {
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")!)
                        }
                        .buttonStyle(.link)
                    }
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Section {
                DatePicker(model.t("On the day, at", "सोही दिन, समय"), selection: reminderTime, displayedComponents: .hourAndMinute)
                Toggle(model.t("Also the evening before, at 7 PM", "अघिल्लो साँझ ७ बजे पनि"), isOn: $model.settings.notifyDayBefore)
                Toggle(model.t("Public holidays only", "सार्वजनिक बिदा मात्र"), isOn: $model.settings.notifyHolidaysOnly)
                LabeledContent("") {
                    Button(model.t("Send Test Notification", "परीक्षण सूचना पठाउनुहोस्")) {
                        NotificationService.shared.sendTest(lang: model.lang)
                    }
                }
            }
            .disabled(!model.settings.notificationsEnabled)
        }
        .formStyle(.grouped)
        .task { denied = model.settings.notificationsEnabled ? await NotificationService.shared.authorizationDenied() : false }
    }

    private var reminderTime: Binding<Date> {
        Binding(
            get: { Calendar.current.date(bySettingHour: model.settings.notifyHour, minute: model.settings.notifyMinute, second: 0, of: Date()) ?? Date() },
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
    private var _copiedFeed = State<Bool>(initialValue: false)
    private var copiedFeed: Bool { get { _copiedFeed.wrappedValue } nonmutating set { _copiedFeed.wrappedValue = newValue } }

    var body: some View {
        let service = model.calendarService
        Form {
            Section {
                Toggle(model.t("Show my Calendar events", "मेरा क्यालेन्डर कार्यक्रम देखाउनुहोस्"), isOn: Binding(
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
                Text(model.t("Events appear under the selected day in the calendar.", "छानिएको दिनमुनि कार्यक्रम देखिन्छन्।"))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Section {
                LabeledContent(model.t("Nepali Festivals calendar", "Nepali Festivals क्यालेन्डर")) {
                    HStack(spacing: 8) {
                        if working { ProgressView().controlSize(.small) }
                        Button(model.t("Add or Update", "थप्नुहोस्")) {
                            working = true
                            Task {
                                message = await service.syncFestivals(lang: model.cal)
                                working = false
                            }
                        }
                        Button(model.t("Remove", "हटाउनुहोस्")) { message = service.removeFestivalCalendar(lang: model.lang) }
                    }
                }
                LabeledContent(model.t("File", "फाइल")) {
                    Button(model.t("Export .ics…", ".ics निर्यात…")) { ICSExport.run(lang: model.cal) }
                }
                LabeledContent(model.t("Google Calendar, Outlook", "गुगल क्यालेन्डर, आउटलुक")) {
                    Button(copiedFeed ? model.t("Copied", "कपी भयो") : model.t("Copy Feed URL", "फिड URL कपी")) {
                        Clipboard.copy(AppInfo.feedURL(model.cal))
                        copiedFeed = true
                    }
                    .help(AppInfo.feedURL(model.cal))
                }
            } footer: {
                Text(message ?? model.t("Adds this year’s and next year’s festivals to a calendar called Nepali Festivals. The feed URL keeps any calendar app up to date.",
                                        "यो र अर्को वर्षका चाडपर्व Nepali Festivals नामको क्यालेन्डरमा थपिन्छन्। फिड URL ले जुनसुकै क्यालेन्डर एपलाई अपडेट राख्छ।"))
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
            Text("Nepali Patro")
                .font(.title2.weight(.semibold))
            Text(model.t("Version \(AppInfo.version) (\(AppInfo.build))", "संस्करण \(AppInfo.version) (\(AppInfo.build))"))
                .font(.callout)
                .foregroundStyle(.secondary)
            Text(model.t("A Nepali calendar for the menu bar that follows Nepal time.",
                         "नेपालको समय पछ्याउने मेनु बारको नेपाली पात्रो।"))
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
