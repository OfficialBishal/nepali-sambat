import SambatCore
import SwiftUI

/// A Bikram Sambat month laid out Sunday-first as a box grid, as in a printed patro. A day is marked
/// by its whole box: filled with the accent for today, tinted for the selection, outlined for today
/// on the other clock.
public struct MonthGrid: View {
    public struct Metrics: Sendable {
        public var cellHeight: CGFloat
        public var numeralSize: CGFloat
        /// Height of the numeral's row.
        public var numeralRow: CGFloat
        /// Space at the top of the box.
        public var numeralTop: CGFloat
        /// Horizontal inset of the day mark.
        public var markInset: CGFloat
        /// Always draw at least this many rows, so the grid keeps one height from month to month.
        public var minRows: Int
        public var showAD: Bool
        public var showTithi: Bool
        public var interactive: Bool

        public init(cellHeight: CGFloat = 44, numeralSize: CGFloat = 15, numeralRow: CGFloat = 26, numeralTop: CGFloat = 6,
                    markInset: CGFloat = 0, minRows: Int = 6,
                    showAD: Bool = true, showTithi: Bool = true, interactive: Bool = true) {
            self.cellHeight = cellHeight
            self.numeralSize = numeralSize
            self.numeralRow = numeralRow
            self.numeralTop = numeralTop
            self.markInset = markInset
            self.minRows = minRows
            self.showAD = showAD
            self.showTithi = showTithi
            self.interactive = interactive
        }
    }

    let year: Int
    let month: Int
    let todayJDN: Int
    let otherTodayJDN: Int?
    let selectedJDN: Int?
    let lang: Language
    let palette: Palette
    let metrics: Metrics
    let onSelect: ((Int) -> Void)?

    /// - Parameters:
    ///   - otherTodayJDN: "today" on the other clock (the Mac's when following Nepal, or vice versa),
    ///     drawn as a thin ring when it differs.
    ///   - lang: the calendar language (numerals, weekday names, tithi).
    public init(year: Int, month: Int, todayJDN: Int, otherTodayJDN: Int? = nil, selectedJDN: Int? = nil,
                lang: Language, palette: Palette, metrics: Metrics = Metrics(), onSelect: ((Int) -> Void)? = nil) {
        self.year = year
        self.month = month
        self.todayJDN = todayJDN
        self.otherTodayJDN = otherTodayJDN
        self.selectedJDN = selectedJDN
        self.lang = lang
        self.palette = palette
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

        VStack(spacing: 0) {
            WeekdayHeader(lang: lang)
            Grid(horizontalSpacing: 0, verticalSpacing: 0) {
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
                                    lang: lang, palette: palette, metrics: metrics, onSelect: onSelect)
                        } else {
                            Color.clear.frame(maxWidth: .infinity).frame(height: metrics.cellHeight)
                        }
                    }
                }
            }
            }
            .background(BoxLines(rows: rows, columns: 7))
        }
    }
}

/// Weekday initials over a grid's columns, Saturday in holiday red.
public struct WeekdayHeader: View {
    let lang: Language

    public init(lang: Language) {
        self.lang = lang
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { wd in
                Text(Formatter.weekday(wd, lang, short: true))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(wd == 6 ? AnyShapeStyle(Palette.holiday) : AnyShapeStyle(.quiet))
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.bottom, 5)
        .accessibilityHidden(true)
    }
}

/// The hairlines of a box grid: every cell a box, as in a printed patro.
public struct BoxLines: View {
    let rows: Int
    let columns: Int

    public init(rows: Int, columns: Int) {
        self.rows = rows
        self.columns = columns
    }

    public var body: some View {
        Canvas { context, size in
            var path = Path()
            let w = size.width / CGFloat(columns), h = size.height / CGFloat(rows)
            for c in 0...columns {
                let x = min(max(CGFloat(c) * w, 0.25), size.width - 0.25)
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }
            for r in 0...rows {
                let y = min(max(CGFloat(r) * h, 0.25), size.height - 0.25)
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(path, with: .color(Color.primary.opacity(0.1)), lineWidth: 0.5)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct DayCell: View {
    let jdn: Int
    let day: Int
    let events: [CalendarEvent]
    let isToday: Bool
    let isOtherToday: Bool
    let isSelected: Bool
    let lang: Language
    let palette: Palette
    let metrics: MonthGrid.Metrics
    let onSelect: ((Int) -> Void)?

    @Environment(\.colorSchemeContrast) private var contrast
    var hovered = State(initialValue: false)

    var body: some View {
        let ad = ADDate(jdn: jdn)
        let weekday = JDN.weekday(jdn)
        let isHoliday = weekday == 6 || events.contains { $0.isPublicHoliday }
        let marker = EventDot.kind(for: events)
        let panchang = metrics.showTithi ? Panchang.shared.day(jdn) : nil

        let minor: AnyShapeStyle = isToday ? AnyShapeStyle(palette.onAccent.opacity(0.85)) : AnyShapeStyle(.quiet)

        VStack(spacing: 0) {
            if metrics.showAD {
                // Top line of the box: festival dot on the left, the AD day on the right.
                HStack(spacing: 2) {
                    if let marker {
                        EventDot(marker, size: 5)
                            .overlay { if isToday { Circle().strokeBorder(palette.onAccent, lineWidth: 1) } }
                    }
                    Spacer(minLength: 0)
                    Text(verbatim: adLabel(ad))
                        .font(.system(size: 8.5))
                        .monospacedDigit()
                        .foregroundStyle(minor)
                        .lineLimit(1)
                }
                .frame(height: 11)
                .padding(.horizontal, 4)
            }
            Text(verbatim: Formatter.digits(day, lang))
                .font(.system(size: metrics.numeralSize, weight: isToday ? .semibold : .regular))
                .foregroundStyle(numeralStyle(isHoliday: isHoliday))
                .frame(height: metrics.numeralRow)

            if let p = panchang {
                Text(verbatim: Formatter.tithiOnly(p.tithi, lang))
                    .font(lang == .english ? .system(size: 8.5).width(.condensed) : .system(size: 9))
                    .fontWeight(p.isPurnima || p.isAunsi ? .semibold : .regular)
                    .foregroundStyle(minor)
                    .lineLimit(1)
                    .allowsTightening(true)
                    .frame(height: 10)
            }
        }
        .padding(.top, metrics.numeralTop)
        .frame(maxWidth: .infinity)
        .frame(height: metrics.cellHeight, alignment: .top)
        .overlay(alignment: .topLeading) {
            // Without the AD line (compact grids) the dot keeps to the corner.
            if !metrics.showAD, let marker {
                EventDot(marker, size: 5)
                    .padding(.top, 4)
                    .padding(.leading, 4)
            }
        }
        .background { DayMark(isToday: isToday, isSelected: isSelected, isOtherToday: isOtherToday,
                              isHovered: metrics.interactive && hovered.wrappedValue, accent: palette.accent,
                              horizontalInset: metrics.markInset) }
        .contentShape(Rectangle())
        .onHover { inside in if metrics.interactive { hovered.wrappedValue = inside } }
        .onTapGesture { onSelect?(jdn) }
        .help(helpText)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText(ad: ad, weekday: weekday))
        .accessibilityAddTraits(isToday || isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { onSelect?(jdn) }
    }

    private func numeralStyle(isHoliday: Bool) -> AnyShapeStyle {
        if isToday { return AnyShapeStyle(palette.onAccent) }
        return isHoliday ? AnyShapeStyle(Palette.holiday) : AnyShapeStyle(.primary)
    }

    /// The AD day, with its month on the 1st (the month bar above names the range).
    private func adLabel(_ ad: ADDate) -> String {
        ad.day == 1 ? Formatter.adShort(ad, .english) : "\(ad.day)"
    }

    private var helpText: String {
        var lines: [String] = []
        if isToday { lines.append(lang == .nepali ? "नेपालमा आज" : "Today in Nepal") }
        if isOtherToday { lines.append(lang == .nepali ? "यहाँ आज" : "Today where you are") }
        lines += events.map { $0.name(lang) }
        return lines.joined(separator: "\n")
    }

    private func accessibilityText(ad: ADDate, weekday: Int) -> String {
        guard let bs = BSDate(jdn: jdn) else { return "" }
        var parts = [Formatter.dateFull(bs, weekday: weekday, lang), Formatter.adLong(ad, .english)]
        if isToday { parts.insert(lang == .nepali ? "नेपालमा आज" : "Today in Nepal", at: 0) }
        if isOtherToday { parts.insert(lang == .nepali ? "यहाँ आज" : "Today where you are", at: 0) }
        parts += events.map { $0.isPublicHoliday ? "\($0.name(lang)), \(lang == .nepali ? "सार्वजनिक बिदा" : "public holiday")" : $0.name(lang) }
        return parts.joined(separator: ", ")
    }
}

/// How a day is marked in any grid: its whole box. Filled with the accent for today, tinted for
/// the selection, outlined for today on the other clock.
public struct DayMark: View {
    let isToday: Bool
    let isSelected: Bool
    let isOtherToday: Bool
    let isHovered: Bool
    let accent: Color
    let horizontalInset: CGFloat

    @Environment(\.colorSchemeContrast) private var contrast

    public init(isToday: Bool, isSelected: Bool, isOtherToday: Bool, isHovered: Bool = false, accent: Color,
                horizontalInset: CGFloat = 0) {
        self.isToday = isToday
        self.isSelected = isSelected
        self.isOtherToday = isOtherToday
        self.isHovered = isHovered
        self.accent = accent
        self.horizontalInset = horizontalInset
    }

    public var body: some View {
        Group {
            if isToday {
                Rectangle().fill(accent)
            } else if isSelected {
                Rectangle().fill(Color.primary.opacity(contrast == .increased ? 0.2 : 0.1))
            } else if isOtherToday {
                Rectangle().strokeBorder(Color.primary.opacity(0.5), lineWidth: 1.5)
            } else if isHovered {
                Rectangle().fill(Color.primary.opacity(0.05))
            }
        }
        .padding(.horizontal, horizontalInset)
    }
}
