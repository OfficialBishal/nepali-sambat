import PatroCore
import PatroUI
import SwiftUI
import WidgetKit
#if DEBUG
import AppKit
#endif

struct PatroEntry: TimelineEntry {
    let date: Date
    let jdn: Int
    let settings: SharedSettings
}

/// One entry per day, each starting exactly at the day change (midnight in Nepal by default),
/// so the widget flips with Nepal even when the Mac is in another time zone.
struct PatroProvider: TimelineProvider {
    func placeholder(in context: Context) -> PatroEntry {
        entry(at: Date(), settings: SharedSettings())
    }

    func getSnapshot(in context: Context, completion: @escaping (PatroEntry) -> Void) {
        completion(entry(at: Date(), settings: SharedSettings.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PatroEntry>) -> Void) {
        let settings = SharedSettings.load()
        var entries = [entry(at: Date(), settings: settings)]
        var t = Date()
        for _ in 0..<8 {
            t = NepalTime.nextDayChange(after: t, basis: settings.basis).addingTimeInterval(1)
            entries.append(entry(at: t, settings: settings))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func entry(at date: Date, settings: SharedSettings) -> PatroEntry {
        PatroEntry(date: date, jdn: JDN.of(date, in: settings.basis.timeZone), settings: settings)
    }
}

struct WidgetTheme {
    static func resolve(_ settings: SharedSettings, _ scheme: ColorScheme) -> Theme {
        Theme.resolve(settings.themeID, systemIsDark: scheme == .dark)
    }
}

// MARK: Today

struct TodayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var scheme
    let entry: PatroEntry

    var body: some View {
        let theme = WidgetTheme.resolve(entry.settings, scheme)
        Group {
            if family == .systemMedium {
                HStack(spacing: 14) {
                    TodayBlock(entry: entry, theme: theme)
                    Rectangle().fill(theme.secondary.opacity(0.2)).frame(width: 0.5)
                    UpcomingList(entry: entry, theme: theme, limit: 4)
                }
            } else {
                TodayBlock(entry: entry, theme: theme)
            }
        }
        .foregroundStyle(theme.primary)
        .containerBackground(for: .widget) { theme.background }
    }
}

struct TodayBlock: View {
    let entry: PatroEntry
    let theme: Theme

    var body: some View {
        let lang = entry.settings.language
        let bs = BSDate(jdn: entry.jdn) ?? BSDate(year: 2083, month: 1, day: 1)
        let ad = ADDate(jdn: entry.jdn)
        let weekday = JDN.weekday(entry.jdn)
        let p = Panchang.shared.day(entry.jdn)
        let holiday = weekday == 6 || FestivalEngine.shared.events(on: entry.jdn).contains { $0.isPublicHoliday }
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(Formatter.weekday(weekday, lang))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(holiday ? theme.holiday : theme.accent)
                Spacer(minLength: 0)
                if entry.settings.basis == .nepal {
                    Text("🇳🇵").font(.system(size: 10))
                }
            }
            Text(Formatter.digits(bs.day, lang))
                .font(.system(size: 50, weight: .bold, design: .rounded))
                .foregroundStyle(holiday ? theme.holiday : theme.primary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(verbatim: "\(Formatter.bsMonth(bs.month, lang)) \(Formatter.digits(bs.year, lang))")
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
            Spacer(minLength: 2)
            if entry.settings.showTithi {
                Text(Formatter.tithiName(p, lang))
                    .font(.system(size: 9.5))
                    .foregroundStyle(theme.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Text(Formatter.adLong(ad, .english))
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(theme.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

struct UpcomingList: View {
    let entry: PatroEntry
    let theme: Theme
    let limit: Int

    var body: some View {
        let lang = entry.settings.language
        let items = upcoming()
        VStack(alignment: .leading, spacing: 5) {
            Text(lang == .nepali ? "आगामी" : "UPCOMING")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(theme.secondary)
            ForEach(items, id: \.id) { e in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Circle().fill(e.isPublicHoliday ? theme.holiday : theme.festival).frame(width: 5, height: 5)
                    Text(e.name(lang))
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                    Spacer(minLength: 2)
                    Text(Formatter.relativeDays(e.jdn - entry.jdn, lang))
                        .font(.system(size: 9.5))
                        .foregroundStyle(theme.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func upcoming() -> [CalendarEvent] {
        var seen = Set<String>()
        return FestivalEngine.shared.events(from: entry.jdn, to: entry.jdn + 120)
            .filter { $0.category != .observance }
            .filter { seen.insert($0.nameEn).inserted }
            .prefix(limit)
            .map { $0 }
    }
}

struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NepaliPatroToday", provider: PatroProvider()) { entry in
            TodayWidgetView(entry: entry)
        }
        .configurationDisplayName("Nepali Date")
        .description("Today's Nepali date and tithi, following Nepal time.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: Month

struct MonthWidgetView: View {
    @Environment(\.colorScheme) private var scheme
    let entry: PatroEntry

    var body: some View {
        let theme = WidgetTheme.resolve(entry.settings, scheme)
        let lang = entry.settings.language
        let bs = BSDate(jdn: entry.jdn) ?? BSDate(year: 2083, month: 1, day: 1)
        let start = BSCalendar.startJDN(year: bs.year, month: bs.month) ?? entry.jdn
        let len = BSCalendar.daysInMonth(year: bs.year, month: bs.month) ?? 30
        let rows = (JDN.weekday(start) + len + 6) / 7
        let a = ADDate(jdn: start), b = ADDate(jdn: start + len - 1)
        let todayEvents = FestivalEngine.shared.events(on: entry.jdn)
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: "\(Formatter.bsMonth(bs.month, lang)) \(Formatter.digits(bs.year, lang))")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                Spacer()
                Text(verbatim: "\(Formatter.adMonth(a.month, .english, short: true)) – \(Formatter.adMonth(b.month, .english, short: true)) \(b.year)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(theme.secondary)
            }
            MonthGrid(year: bs.year, month: bs.month, todayJDN: entry.jdn, lang: lang, theme: theme,
                      metrics: .init(cellHeight: rows == 6 ? 37 : 44, dayFont: 15, smallFont: 7.5, spacing: 1.5,
                                     showAD: true, showTithi: entry.settings.showTithi))
            Spacer(minLength: 0)
            HStack(spacing: 5) {
                Text(Formatter.tithiName(Panchang.shared.day(entry.jdn), lang))
                    .foregroundStyle(theme.secondary)
                if let e = todayEvents.first {
                    Text(verbatim: "· \(e.name(lang))").foregroundStyle(e.isPublicHoliday ? theme.holiday : theme.festival)
                }
            }
            .font(.system(size: 10, weight: .medium))
            .lineLimit(1)
        }
        .foregroundStyle(theme.primary)
        .containerBackground(for: .widget) { theme.background }
    }
}

struct MonthWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NepaliPatroMonth", provider: PatroProvider()) { entry in
            MonthWidgetView(entry: entry)
        }
        .configurationDisplayName("Nepali Month")
        .description("This month in the Nepali calendar with holidays and tithis.")
        .supportedFamilies([.systemLarge])
    }
}

struct NepaliPatroWidgets: WidgetBundle {
    var body: some Widget {
        TodayWidget()
        MonthWidget()
    }
}

@main
enum WidgetMain {
    static func main() {
        #if DEBUG
        if let i = CommandLine.arguments.firstIndex(of: "--render"), i + 1 < CommandLine.arguments.count {
            MainActor.assumeIsolated { renderPreviews(to: URL(fileURLWithPath: CommandLine.arguments[i + 1])) }
            return
        }
        #endif
        NepaliPatroWidgets.main()
    }
}

#if DEBUG
/// Debug builds only: writes PNG previews of each widget family.
@MainActor
func renderPreviews(to dir: URL) {
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    for (themeID, lang, scheme) in [("system", Language.nepali, ColorScheme.light), ("system", .english, .dark), ("himalaya", .english, .light)] {
        var settings = SharedSettings()
        settings.themeID = themeID
        settings.language = lang
        let entry = PatroEntry(date: Date(), jdn: NepalTime.todayJDN(), settings: settings)
        let theme = WidgetTheme.resolve(settings, scheme)
        func save<V: View>(_ view: V, _ size: CGSize, _ name: String) {
            let content = view.padding(16).frame(width: size.width, height: size.height)
                .background(theme.background).foregroundStyle(theme.primary)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .environment(\.colorScheme, scheme)
            let r = ImageRenderer(content: content)
            r.scale = 2
            if let img = r.nsImage, let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
               let png = rep.representation(using: .png, properties: [:]) {
                try? png.write(to: dir.appendingPathComponent("\(name)-\(themeID)-\(lang.rawValue).png"))
            }
        }
        save(TodayBlock(entry: entry, theme: theme), CGSize(width: 170, height: 170), "small")
        save(HStack(spacing: 14) {
            TodayBlock(entry: entry, theme: theme)
            Rectangle().fill(theme.secondary.opacity(0.2)).frame(width: 0.5)
            UpcomingList(entry: entry, theme: theme, limit: 4)
        }, CGSize(width: 364, height: 170), "medium")
        save(MonthWidgetView(entry: entry), CGSize(width: 364, height: 382), "large")
    }
}
#endif
