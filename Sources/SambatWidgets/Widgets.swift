import SambatCore
import SambatUI
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
                TodayMedium(entry: entry)
            } else {
                TodayBlock(entry: entry)
            }
        }
        .containerBackground(.background, for: .widget)
    }
}

/// Today on the left, the next three festivals on the right.
struct TodayMedium: View {
    let entry: PatroEntry

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            TodayBlock(entry: entry).frame(width: 112)
            UpcomingList(entry: entry, limit: 3)
        }
    }
}

struct TodayBlock: View {
    let entry: PatroEntry

    var body: some View {
        let cal = entry.settings.calendarLanguage
        let bs = BSDate(jdn: entry.jdn) ?? BSDate(year: 2083, month: 1, day: 1)
        let ad = ADDate(jdn: entry.jdn)
        let weekday = JDN.weekday(entry.jdn)
        let p = Panchang.shared.day(entry.jdn)
        let events = FestivalEngine.shared.events(on: entry.jdn).filter { $0.category != .observance }
        VStack(alignment: .leading, spacing: 0) {
            Text(Formatter.weekday(weekday, cal))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(weekday == 6 ? Loom.madder : Loom.saffron)
            Text(verbatim: Formatter.digits(bs.day, cal))
                .font(.system(size: 40, weight: .semibold))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(verbatim: "\(Formatter.bsMonth(bs.month, cal)) \(Formatter.digits(bs.year, cal))")
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
            Spacer(minLength: 4)
            if entry.settings.showTithi {
                TithiBand(tithi: p.tithi, lang: entry.settings.language, height: 9)
                    .padding(.bottom, 4)
            }
            if let e = events.first {
                HStack(spacing: 5) {
                    if let kind = EventMarker.kind(for: e) { EventMarker(kind, size: 6) }
                    Text(e.name(cal))
                        .foregroundStyle(e.isPublicHoliday ? AnyShapeStyle(Loom.madder) : AnyShapeStyle(.primary))
                }
                .font(.system(size: 10.5, weight: .semibold))
                .lineLimit(1)
            } else {
                Text(Formatter.tithiShort(p, cal))
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Text(verbatim: "\(Formatter.adMonth(ad.month, .english, short: true)) \(ad.day), \(ad.year)")
                .font(.system(size: 10.5))
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
        VStack(alignment: .leading, spacing: 7) {
            Text(ui == .nepali ? "आउँदै गरेका" : "Coming up")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            ForEach(upcoming(), id: \.id) { e in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Group {
                        if let kind = EventMarker.kind(for: e) { EventMarker(kind, size: 6.5) }
                    }
                    .frame(width: 8)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(e.name(cal))
                            .font(.system(size: 11.5, weight: .medium))
                            .lineLimit(1)
                        HStack(spacing: 4) {
                            Text(verbatim: bsShort(e.jdn, cal))
                            Spacer(minLength: 4)
                            Text(verbatim: away(e.jdn - entry.jdn, ui))
                        }
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func bsShort(_ jdn: Int, _ lang: Language) -> String {
        guard let bs = BSDate(jdn: jdn) else { return "" }
        return "\(Formatter.bsMonth(bs.month, lang)) \(Formatter.digits(bs.day, lang))"
    }

    /// Short distance for a narrow column: "Tomorrow", "21 days".
    private func away(_ days: Int, _ lang: Language) -> String {
        if days == 1 { return Formatter.relativeDays(1, lang) }
        return lang == .nepali ? "\(Formatter.digits(days, .nepali)) दिन" : "\(days) days"
    }

    private func upcoming() -> [CalendarEvent] {
        var seen = Set<String>()
        return FestivalEngine.shared.events(from: entry.jdn + 1, to: entry.jdn + 120)
            .filter { $0.category != .observance }
            .filter { seen.insert($0.nameEn).inserted }
            .prefix(limit)
            .map { $0 }
    }
}

struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SambatToday", provider: PatroProvider()) { entry in
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
            .containerBackground(.background, for: .widget)
    }
}

struct MonthWidgetContent: View {
    let entry: PatroEntry

    var body: some View {
        let cal = entry.settings.calendarLanguage
        let bs = BSDate(jdn: entry.jdn) ?? BSDate(year: 2083, month: 1, day: 1)
        let start = BSCalendar.startJDN(year: bs.year, month: bs.month) ?? entry.jdn
        let len = BSCalendar.daysInMonth(year: bs.year, month: bs.month) ?? 30
        let rows = MonthGrid.rows(year: bs.year, month: bs.month)
        let a = ADDate(jdn: start), b = ADDate(jdn: start + len - 1)
        let todayEvent = FestivalEngine.shared.events(on: entry.jdn).first { $0.category != .observance }
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: "\(Formatter.bsMonth(bs.month, cal)) \(Formatter.digits(bs.year, cal))")
                    .font(.system(size: 16, weight: .semibold))
                Spacer(minLength: 6)
                Text(verbatim: "\(Formatter.adMonth(a.month, .english, short: true)) – \(Formatter.adMonth(b.month, .english, short: true)) \(b.year)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            MonthGrid(year: bs.year, month: bs.month, todayJDN: entry.jdn, lang: cal,
                      metrics: .init(cellHeight: rows == 6 ? 40 : 46, rowSpacing: rows == 6 ? 0 : 2,
                                     numeralSize: 14, marker: rows == 6 ? 23 : 26,
                                     showAD: true, showTithi: entry.settings.showTithi, interactive: false))
            Spacer(minLength: 0)
            TithiBand(tithi: Panchang.shared.day(entry.jdn).tithi, lang: entry.settings.language, height: 12)
            HStack(spacing: 10) {
                Text(Formatter.tithiShort(Panchang.shared.day(entry.jdn), cal))
                    .foregroundStyle(.secondary)
                if let e = todayEvent {
                    HStack(spacing: 5) {
                        if let kind = EventMarker.kind(for: e) { EventMarker(kind, size: 6) }
                        Text(e.name(cal)).foregroundStyle(e.isPublicHoliday ? AnyShapeStyle(Loom.madder) : AnyShapeStyle(.primary))
                    }
                }
            }
            .font(.system(size: 11))
            .lineLimit(1)
        }
    }
}

struct MonthWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SambatMonth", provider: PatroProvider()) { entry in
            MonthWidgetView(entry: entry)
        }
        .configurationDisplayName("Nepali Month")
        .description("This month in the Nepali calendar with holidays and tithis.")
        .supportedFamilies([.systemLarge])
    }
}

struct SambatWidgets: WidgetBundle {
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
        SambatWidgets.main()
    }
}

#if DEBUG
/// Debug builds only: writes PNG previews of each widget family.
@MainActor
func renderPreviews(to dir: URL) {
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let configs: [(String, ColorScheme, Language)] = [("ne", .light, .nepali), ("en", .dark, .english)]
    for (name, scheme, cal) in configs {
        var settings = SharedSettings()
        settings.calendarLanguage = cal
        let entry = PatroEntry(date: Date(), jdn: NepalTime.todayJDN(), settings: settings)
        func save<V: View>(_ view: V, _ size: CGSize, _ kind: String) {
            let content = view
                .padding(16)
                .frame(width: size.width, height: size.height)
                .background(Color(nsColor: scheme == .dark ? NSColor(white: 0.16, alpha: 1) : .white))
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
        save(TodayMedium(entry: entry), CGSize(width: 364, height: 170), "medium")
        save(MonthWidgetContent(entry: entry), CGSize(width: 364, height: 382), "large")
    }
}
#endif
