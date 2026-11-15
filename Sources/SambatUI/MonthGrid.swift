import SambatCore
import SwiftUI

/// A Bikram Sambat month, Sunday first. Marks are soft rounded squares: saffron for Nepal's
/// today, an outline for the selection, a madder wash for a public holiday. Each cell reads top to
/// bottom as the AD date (with the festival marker beside it), the BS numeral, then the tithi.
public struct MonthGrid: View {
    public struct Metrics: Sendable {
        public var cellHeight: CGFloat
        public var rowSpacing: CGFloat
        public var numeralSize: CGFloat
        public var marker: CGFloat
        public var showAD: Bool
        public var showTithi: Bool
        /// Pad short months with empty rows so the grid keeps one height (compact pickers).
        public var minRows: Int
        public var interactive: Bool
        /// Draw for the dark loom field (widgets), whatever the appearance.
        public var onField: Bool

        public init(cellHeight: CGFloat = 48, rowSpacing: CGFloat = 2, numeralSize: CGFloat = 15, marker: CGFloat = 28,
                    showAD: Bool = true, showTithi: Bool = true, interactive: Bool = true, onField: Bool = false,
                    minRows: Int = 0) {
            self.minRows = minRows
            self.cellHeight = cellHeight
            self.rowSpacing = rowSpacing
            self.numeralSize = numeralSize
            self.marker = marker
            self.showAD = showAD
            self.showTithi = showTithi
            self.interactive = interactive
            self.onField = onField
        }
    }

    let year: Int
    let month: Int
    let todayJDN: Int
    let otherTodayJDN: Int?
    let selectedJDN: Int?
    let lang: Language
    let uiLanguage: Language
    let metrics: Metrics
    let onSelect: ((Int) -> Void)?

    /// - Parameters:
    ///   - otherTodayJDN: "today" on the other clock (this Mac's while following Nepal, or the reverse),
    ///     outlined when it differs.
    ///   - lang: the calendar language (numerals, weekday names, tithi).
    public init(year: Int, month: Int, todayJDN: Int, otherTodayJDN: Int? = nil, selectedJDN: Int? = nil,
                lang: Language, uiLanguage: Language = .english, metrics: Metrics = Metrics(),
                onSelect: ((Int) -> Void)? = nil) {
        self.year = year
        self.month = month
        self.todayJDN = todayJDN
        self.otherTodayJDN = otherTodayJDN
        self.selectedJDN = selectedJDN
        self.lang = lang
        self.uiLanguage = uiLanguage
        self.metrics = metrics
        self.onSelect = onSelect
    }

    public static func rows(year: Int, month: Int) -> Int {
        guard let start = BSCalendar.startJDN(year: year, month: month),
              let len = BSCalendar.daysInMonth(year: year, month: month) else { return 5 }
        return (JDN.weekday(start) + len + 6) / 7
    }

    public var body: some View {
        let start = BSCalendar.startJDN(year: year, month: month) ?? 0
        let length = BSCalendar.daysInMonth(year: year, month: month) ?? 30
        let lead = JDN.weekday(start)
        let rows = max(metrics.minRows, (lead + length + 6) / 7)
        let events = FestivalEngine.shared.eventsByDay(year: year, month: month)
        let holidayRed = metrics.onField ? Loom.madder : Loom.madder

        Grid(horizontalSpacing: 0, verticalSpacing: metrics.rowSpacing) {
            GridRow {
                ForEach(0..<7, id: \.self) { wd in
                    Text(Formatter.weekday(wd, lang, short: true))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(wd == 6 ? AnyShapeStyle(holidayRed) : AnyShapeStyle(.quiet))
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 3)
                        .accessibilityHidden(true)
                }
            }
            ForEach(0..<rows, id: \.self) { row in
                GridRow {
                    ForEach(0..<7, id: \.self) { col in
                        let index = row * 7 + col - lead
                        if index >= 0 && index < length {
                            let jdn = start + index
                            DayCell(jdn: jdn, day: index + 1, events: events[jdn] ?? [],
                                    isToday: jdn == todayJDN,
                                    isOtherToday: otherTodayJDN == jdn && otherTodayJDN != todayJDN,
                                    isSelected: jdn == selectedJDN && jdn != todayJDN,
                                    isFirstShown: index == 0,
                                    lang: lang, uiLanguage: uiLanguage, metrics: metrics, onSelect: onSelect)
                        } else {
                            Color.clear.frame(maxWidth: .infinity).frame(height: metrics.cellHeight)
                        }
                    }
                }
            }
        }
    }
}

struct DayCell: View {
    let jdn: Int
    let day: Int
    let events: [CalendarEvent]
    let isToday: Bool
    let isOtherToday: Bool
    let isSelected: Bool
    let isFirstShown: Bool
    let lang: Language
    let uiLanguage: Language
    let metrics: MonthGrid.Metrics
    let onSelect: ((Int) -> Void)?

    @Environment(\.colorSchemeContrast) private var contrast
    var hovered = State(initialValue: false)

    var body: some View {
        let ad = ADDate(jdn: jdn)
        let weekday = JDN.weekday(jdn)
        let isPublicHoliday = events.contains { $0.isPublicHoliday }
        let marker = EventMarker.kind(for: events)
        let panchang = metrics.showTithi ? Panchang.shared.day(jdn) : nil

        VStack(spacing: 1) {
            if metrics.showAD {
                HStack(spacing: 3) {
                    if let marker { EventMarker(marker, size: 6, onField: metrics.onField) }
                    Text(verbatim: adLabel(ad))
                        .font(.system(size: 9, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(.quiet)
                        .lineLimit(1)
                }
                .frame(height: 10)
            }
            ZStack {
                if isToday {
                    DayMark().fill(Loom.saffron)
                } else if isPublicHoliday {
                    DayMark().fill(Loom.madderWash)
                } else if metrics.interactive && hovered.wrappedValue {
                    DayMark().fill(Color.primary.opacity(0.07))
                }
                if isSelected && !isToday {
                    DayMark().strokeBorder(Color.primary.opacity(contrast == .increased ? 0.9 : 0.7), lineWidth: 1.5)
                } else if isOtherToday {
                    DayMark().strokeBorder(Loom.saffron, lineWidth: 1.5)
                }
                Text(verbatim: Formatter.digits(day, lang))
                    .font(.system(size: metrics.numeralSize, weight: isToday ? .bold : .medium))
                    .monospacedDigit()
                    .foregroundStyle(isToday ? AnyShapeStyle(Loom.ink) : AnyShapeStyle(.primary))
            }
            .frame(width: metrics.marker, height: metrics.marker)
            if let p = panchang {
                Text(verbatim: Formatter.tithiOnly(p.tithi, lang))
                    .font(lang == .english ? .system(size: 8.5).width(.condensed) : .system(size: 9))
                    .fontWeight(p.isPurnima || p.isAunsi ? .semibold : .regular)
                    .foregroundStyle(.quiet)
                    .lineLimit(1)
                    .frame(height: 10)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: metrics.cellHeight)
        .overlay(alignment: .topLeading) {
            // Without the AD line (compact grids) the marker keeps to the cell's corner.
            if !metrics.showAD, let marker {
                EventMarker(marker, size: 5.5, onField: metrics.onField)
                    .padding(.top, 2)
                    .padding(.leading, 3)
            }
        }
        .contentShape(Rectangle())
        .onHover { inside in if metrics.interactive { hovered.wrappedValue = inside } }
        .onTapGesture { onSelect?(jdn) }
        .help(helpText)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText(ad: ad, weekday: weekday))
        .accessibilityAddTraits(isToday || isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { onSelect?(jdn) }
    }

    /// The Gregorian day, with its month on the 1st and on the first day the grid shows.
    private func adLabel(_ ad: ADDate) -> String {
        (ad.day == 1 || isFirstShown) ? Formatter.adShort(ad, .english) : "\(ad.day)"
    }

    private var helpText: String {
        var lines: [String] = []
        if isToday { lines.append(uiLanguage == .nepali ? "नेपालमा आज" : "Today in Nepal") }
        if isOtherToday { lines.append(uiLanguage == .nepali ? "यहाँ आज" : "Today where you are") }
        lines += events.map { $0.name(lang) }
        return lines.joined(separator: "\n")
    }

    private func accessibilityText(ad: ADDate, weekday: Int) -> String {
        guard let bs = BSDate(jdn: jdn) else { return "" }
        var parts = [Formatter.dateFull(bs, weekday: weekday, lang), Formatter.adLong(ad, .english)]
        if isToday { parts.insert(uiLanguage == .nepali ? "नेपालमा आज" : "Today in Nepal", at: 0) }
        if isOtherToday { parts.insert(uiLanguage == .nepali ? "यहाँ आज" : "Today where you are", at: 0) }
        parts += events.map { $0.isPublicHoliday ? "\($0.name(lang)), \(lang == .nepali ? "सार्वजनिक बिदा" : "public holiday")" : $0.name(lang) }
        return parts.joined(separator: ", ")
    }
}
