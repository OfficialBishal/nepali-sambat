import PatroCore
import PatroUI
import SwiftUI

struct SettingsPage: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 12) {
                PageTitle(text: model.t("Settings", "सेटिङ"))
                DateSettings()
                MenuBarSettings()
                AppearanceSettings()
                NotificationSettings()
                CalendarSettings()
                GeneralSettings()
            }
            .padding(12)
        }
        .toggleStyle(.switch)
        .controlSize(.small)
    }
}

struct SettingRow<Trailing: View>: View {
    @Environment(AppModel.self) private var model
    let title: String
    var caption: String? = nil
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 12, weight: .medium))
                if let caption {
                    Text(caption)
                        .font(.system(size: 10))
                        .foregroundStyle(model.theme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 6)
            trailing
        }
    }
}

struct DateSettings: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        let nextChange = NepalTime.nextDayChange(after: model.now, basis: .nepal)
        let localTime = Formatter.time(nextChange, in: .current, model.lang)
        Card {
            SectionLabel(text: model.t("Date", "मिति"))
            VStack(alignment: .leading, spacing: 5) {
                Text(model.t("Today follows", "आजको मिति कुन समयअनुसार")).font(.system(size: 12, weight: .medium))
                Picker("", selection: $model.settings.basis) {
                    Text(model.t("Nepal time", "नेपाल समय")).tag(DateBasis.nepal)
                    Text(model.t("This Mac's time", "यो म्याकको समय")).tag(DateBasis.local)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                Text(model.settings.basis == .nepal
                     ? model.t("The Nepali date changes at midnight in Nepal — \(localTime) your time.",
                               "नेपालको मध्यरातमा मिति फेरिन्छ — तपाईंको समयअनुसार \(localTime)।")
                     : model.t("The Nepali date changes at midnight where you are.",
                               "तपाईं भएको ठाउँको मध्यरातमा मिति फेरिन्छ।"))
                    .font(.system(size: 10))
                    .foregroundStyle(model.theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(model.t("Language", "भाषा")).font(.system(size: 12, weight: .medium))
                Picker("", selection: $model.settings.language) {
                    Text("नेपाली").tag(Language.nepali)
                    Text("English").tag(Language.english)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
        }
    }
}

struct MenuBarSettings: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        let today = model.today
        let wd = JDN.weekday(model.todayJDN)
        Card {
            SectionLabel(text: model.t("Menu bar", "मेनु बार"))
            SettingRow(title: model.t("Format", "ढाँचा")) {
                Picker("", selection: $model.settings.menuFormat) {
                    ForEach(MenuBarFormat.allCases) { f in
                        Text(f == .iconOnly ? model.t("Calendar icon", "क्यालेन्डर आइकन") : f.sample(today, weekday: wd, model.lang)).tag(f)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()
            }
            SettingRow(title: model.t("Show Nepal time", "नेपालको समय देखाउनुहोस्")) {
                Toggle("", isOn: $model.settings.menuShowsNepalTime).labelsHidden()
            }
            if model.settings.menuFormat != .iconOnly {
                SettingRow(title: model.t("Show calendar symbol", "क्यालेन्डर चिन्ह देखाउनुहोस्")) {
                    Toggle("", isOn: $model.settings.menuShowsIcon).labelsHidden()
                }
            }
        }
    }
}

struct AppearanceSettings: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Card {
            SectionLabel(text: model.t("Theme", "थिम"))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ThemeSwatch(id: "system", title: model.t("Auto", "स्वचालित"))
                ForEach(Theme.all) { theme in
                    ThemeSwatch(id: theme.id, title: theme.name(model.lang))
                }
            }
            SettingRow(title: model.t("Show tithi in calendar", "पात्रोमा तिथि देखाउनुहोस्")) {
                Toggle("", isOn: $model.settings.showTithi).labelsHidden()
            }
            SettingRow(title: model.t("Show English dates", "अंग्रेजी मिति देखाउनुहोस्")) {
                Toggle("", isOn: $model.settings.showAD).labelsHidden()
            }
        }
    }
}

struct ThemeSwatch: View {
    @Environment(AppModel.self) private var model
    let id: String
    let title: String

    var body: some View {
        let selected = model.settings.themeID == id
        let current = model.theme
        Button {
            model.settings.themeID = id
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    if id == "system" {
                        HStack(spacing: 0) {
                            Theme.light.background
                            Theme.dark.background
                        }
                        Image(systemName: "circle.lefthalf.filled")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.light.accent)
                    } else {
                        let t = Theme.resolve(id, systemIsDark: false)
                        t.background
                        HStack(spacing: 3) {
                            Text("२९").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(t.primary)
                            Circle().fill(t.accent).frame(width: 7, height: 7)
                        }
                    }
                }
                .frame(height: 34)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(selected ? current.accent : current.secondary.opacity(0.3), lineWidth: selected ? 2 : 0.5)
                )
                Text(title)
                    .font(.system(size: 9.5, weight: selected ? .semibold : .regular))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
