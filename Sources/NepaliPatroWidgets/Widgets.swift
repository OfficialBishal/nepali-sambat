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

// MARK: Today

struct TodayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PatroEntry

    var body: some View {
        Group {
            if family == .systemMedium {
                HStack(alignment: .top, spacing: 16) {
                    TodayBlock(entry: entry)
                    UpcomingList(entry: entry, limit: 4)
                }
            } else {
                TodayBlock(entry: entry)
            }
        }
        .modifier(SchemeOverride(mode: entry.settings.appearance))
        .containerBackground(.background, for: .widget)
    }
}

/// Applies the app's Light/Dark choice; "Auto" leaves the system's scheme in place.
struct SchemeOverride: ViewModifier {
    let mode: AppearanceMode
    @Environment(\.colorScheme) private var system

    func body(content: Content) -> some View {
        content.environment(\.colorScheme, mode.colorScheme ?? system)
    }
}

struct TodayBlock: View {
    let entry: PatroEntry

    var body: some View {
        let cal = entry.settings.calendarLanguage
        let palette = Palette(entry.settings.accent)
        let bs = BSDate(jdn: entry.jdn) ?? BSDate(year: 2083, month: 1, day: 1)
        let ad = ADDate(jdn: entry.jdn)
        let weekday = JDN.weekday(entry.jdn)
        let p = Panchang.shared.day(entry.jdn)
        let holiday = weekday == 6 || FestivalEngine.shared.events(on: entry.jdn).contains { $0.isPublicHoliday }
        VStack(alignment: .leading, spacing: 0) {
            Text(Formatter.weekday(weekday, cal))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(holiday ? Palette.holiday : palette.accent)
            Text(Formatter.digits(bs.day, cal))
                .font(.system(size: 46, weight: .light))
                .foregroundStyle(holiday ? AnyShapeStyle(Palette.holiday) : AnyShapeStyle(.primary))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(verbatim: "\(Formatter.bsMonth(bs.month, cal)) \(Formatter.digits(bs.year, cal))")
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
            Spacer(minLength: 2)
            if entry.settings.showTithi {
                Text(Formatter.tithiName(p, cal))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Text(Formatter.adLong(ad, .english))
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

struct UpcomingList: View {
    let entry: PatroEntry
    let limit: Int

    var body: some View {
        let cal = entry.settings.calendarLanguage
        let ui = entry.settings.language
        VStack(alignment: .leading, spacing: 6) {
            Text(ui == .nepali ? "आगामी" : "Upcoming")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            ForEach(upcoming(), id: \.id) { e in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Circle()
                        .fill(e.isPublicHoliday ? AnyShapeStyle(Palette.holiday) : AnyShapeStyle(.secondary))
                        .frame(width: 5, height: 5)
                    Text(e.name(cal))
                        .font(.system(size: 11.5, weight: .medium))
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(Formatter.relativeDays(e.jdn - entry.jdn, ui))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
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
    let entry: PatroEntry

    var body: some View {
        MonthWidgetContent(entry: entry)
            .modifier(SchemeOverride(mode: entry.settings.appearance))
            .containerBackground(.background, for: .widget)
    }
}

struct MonthWidgetContent: View {
    let entry: PatroEntry

    var body: some View {
        let cal = entry.settings.calendarLanguage
        let palette = Palette(entry.settings.accent)
        let bs = BSDate(jdn: entry.jdn) ?? BSDate(year: 2083, month: 1, day: 1)
        let start = BSCalendar.startJDN(year: bs.year, month: bs.month) ?? entry.jdn
        let len = BSCalendar.daysInMonth(year: bs.year, month: bs.month) ?? 30
        let rows = MonthGrid.rows(year: bs.year, month: bs.month)
        let a = ADDate(jdn: start), b = ADDate(jdn: start + len - 1)
        let todayEvent = FestivalEngine.shared.events(on: entry.jdn).first
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: "\(Formatter.bsMonth(bs.month, cal)) \(Formatter.digits(bs.year, cal))")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Text(verbatim: "\(Formatter.adMonth(a.month, .english, short: true)) – \(Formatter.adMonth(b.month, .english, short: true)) \(b.year)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            MonthGrid(year: bs.year, month: bs.month, todayJDN: entry.jdn, lang: cal, palette: palette,
                      metrics: .init(cellHeight: rows == 6 ? 45 : 53, numeralSize: 15, circle: 26,
                                     showAD: true, showTithi: entry.settings.showTithi, interactive: false))
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                Text(Formatter.tithiName(Panchang.shared.day(entry.jdn), cal))
                    .foregroundStyle(.secondary)
                if let e = todayEvent {
                    Text(e.name(cal)).foregroundStyle(e.isPublicHoliday ? AnyShapeStyle(Palette.holiday) : AnyShapeStyle(.primary))
                }
            }
            .font(.system(size: 11))
            .lineLimit(1)
        }
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
    let configs: [(String, ColorScheme, Language, AccentChoice)] = [
        ("light", .light, .nepali, .system), ("dark", .dark, .nepali, .blue), ("light-en", .light, .english, .teal),
    ]
    for (name, scheme, cal, accent) in configs {
        var settings = SharedSettings()
        settings.calendarLanguage = cal
        settings.accent = accent
        let entry = PatroEntry(date: Date(), jdn: NepalTime.todayJDN(), settings: settings)
        func save<V: View>(_ view: V, _ size: CGSize, _ kind: String) {
            let content = view
                .padding(16)
                .frame(width: size.width, height: size.height)
                .background(scheme == .dark ? Color(white: 0.12) : Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .environment(\.colorScheme, scheme)
            let r = ImageRenderer(content: content)
            r.scale = 2
            if let img = r.nsImage, let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
               let png = rep.representation(using: .png, properties: [:]) {
                try? png.write(to: dir.appendingPathComponent("\(kind)-\(name).png"))
            }
        }
        save(TodayBlock(entry: entry), CGSize(width: 170, height: 170), "small")
        save(HStack(alignment: .top, spacing: 16) {
            TodayBlock(entry: entry)
            UpcomingList(entry: entry, limit: 4)
        }, CGSize(width: 364, height: 170), "medium")
        save(MonthWidgetContent(entry: entry), CGSize(width: 364, height: 382), "large")
    }
}
#endif
