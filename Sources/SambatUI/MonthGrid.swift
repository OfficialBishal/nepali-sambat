import SambatCore
import SwiftUI

/// Size and content options shared by every month grid.
public struct GridMetrics: Sendable {
    public var cellHeight: CGFloat
    public var numeralSize: CGFloat
    /// Draw at least this many rows (0: only the rows the month needs).
    public var minRows: Int
    /// The other calendar's day in the top-right corner of each box.
    public var showCorner: Bool
    public var showTithi: Bool
    public var interactive: Bool

    public init(cellHeight: CGFloat = 46, numeralSize: CGFloat = 15, minRows: Int = 0,
                showCorner: Bool = true, showTithi: Bool = true, interactive: Bool = true) {
        self.cellHeight = cellHeight
        self.numeralSize = numeralSize
        self.minRows = minRows
        self.showCorner = showCorner
        self.showTithi = showTithi
        self.interactive = interactive
    }
}

/// A Bikram Sambat month laid out Sunday-first as a box grid, as in a printed patro.
public struct MonthGrid: View {
    let year: Int
    let month: Int
    let todayJDN: Int
    let otherTodayJDN: Int?
    let selectedJDN: Int?
    let lang: Language
    let palette: Palette
    let metrics: GridMetrics
    let onSelect: ((Int) -> Void)?

    /// - Parameters:
    ///   - otherTodayJDN: "today" on the other clock (the Mac's when following Nepal, or the reverse),
    ///     outlined when it differs.
    ///   - lang: the calendar language (numerals, weekday names, tithi).
    public init(year: Int, month: Int, todayJDN: Int, otherTodayJDN: Int? = nil, selectedJDN: Int? = nil,
                lang: Language, palette: Palette, metrics: GridMetrics = GridMetrics(), onSelect: ((Int) -> Void)? = nil) {
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
        DayGrid(start: BSCalendar.startJDN(year: year, month: month) ?? 0,
                length: BSCalendar.daysInMonth(year: year, month: month) ?? 30,
                primary: .bs, todayJDN: todayJDN, otherTodayJDN: otherTodayJDN, selectedJDN: selectedJDN,
                lang: lang, palette: palette, metrics: metrics, onSelect: onSelect)
    }
}

/// A Gregorian month in the same boxes as the Nepali grid, mirrored: the AD day in the middle, the
/// BS day in the corner, the tithi below. Used to pick an AD date in the converter.
public struct ADMonthGrid: View {
    let year: Int
    let month: Int
    let todayJDN: Int
    let otherTodayJDN: Int?
    let selectedJDN: Int?
    let lang: Language
    let palette: Palette
    let metrics: GridMetrics
    let onSelect: ((Int) -> Void)?

    public init(year: Int, month: Int, todayJDN: Int, otherTodayJDN: Int? = nil, selectedJDN: Int? = nil,
                lang: Language, palette: Palette, metrics: GridMetrics = GridMetrics(), onSelect: ((Int) -> Void)? = nil) {
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

    public var body: some View {
        DayGrid(start: JDN.from(year: year, month: month, day: 1), length: ADDate.daysInMonth(year: year, month: month),
                primary: .ad, todayJDN: todayJDN, otherTodayJDN: otherTodayJDN, selectedJDN: selectedJDN,
                lang: lang, palette: palette, metrics: metrics, onSelect: onSelect)
    }
}

/// Which calendar's day is the big numeral in each box.
enum PrimaryCalendar { case bs, ad }

/// The box grid both month views share: weekday initials, then a box for every day.
struct DayGrid: View {
    let start: Int
    let length: Int
    let primary: PrimaryCalendar
    let todayJDN: Int
    let otherTodayJDN: Int?
    let selectedJDN: Int?
    let lang: Language
    let palette: Palette
    let metrics: GridMetrics
    let onSelect: ((Int) -> Void)?

    var body: some View {
        let lead = JDN.weekday(start)
        let rows = max(metrics.minRows, (lead + length + 6) / 7)
        let events = Dictionary(grouping: FestivalEngine.shared.events(from: start, to: start + length - 1), by: \.jdn)

        VStack(spacing: 0) {
            WeekdayHeader(lang: primary == .bs ? lang : .english)
            Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                ForEach(0..<rows, id: \.self) { row in
                    GridRow {
                        ForEach(0..<7, id: \.self) { col in
                            let index = row * 7 + col - lead
                            if index >= 0 && index < length {
                                let jdn = start + index
                                DayCell(jdn: jdn, primary: primary, events: events[jdn] ?? [],
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

/// One day's box. The numeral sits at the exact centre; the festival dot and the other calendar's
/// day are pinned to the top edge, the tithi to the bottom edge, so nothing pushes the numeral off centre.
struct DayCell: View {
    let jdn: Int
    let primary: PrimaryCalendar
    let events: [CalendarEvent]
    let isToday: Bool
    let isOtherToday: Bool
    let isSelected: Bool
    let lang: Language
    let palette: Palette
    let metrics: GridMetrics
    let onSelect: ((Int) -> Void)?

    var hovered = State(initialValue: false)

    var body: some View {
        let ad = ADDate(jdn: jdn)
        let bs = BSDate(jdn: jdn)
        let weekday = JDN.weekday(jdn)
        let isPublicHoliday = events.contains { $0.isPublicHoliday }
        let isHoliday = weekday == 6 || isPublicHoliday
        let panchang = metrics.showTithi ? Panchang.shared.day(jdn) : nil
        let minor: AnyShapeStyle = isToday ? AnyShapeStyle(palette.onAccent.opacity(0.85)) : AnyShapeStyle(.quiet)
        let numeral = primary == .bs ? Formatter.digits(bs?.day ?? 0, lang) : "\(ad.day)"

        Text(verbatim: numeral)
            .font(.system(size: metrics.numeralSize, weight: isToday ? .semibold : .regular))
            .foregroundStyle(isToday ? AnyShapeStyle(palette.onAccent) : (isHoliday ? AnyShapeStyle(Palette.holiday) : AnyShapeStyle(.primary)))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .frame(height: metrics.cellHeight)
            .overlay(alignment: .top) {
                HStack(spacing: 2) {
                    if let marker = marker(isPublicHoliday: isPublicHoliday) {
                        EventDot(marker, size: 5)
                            .overlay { if isToday { Circle().strokeBorder(palette.onAccent, lineWidth: 1) } }
                    }
                    Spacer(minLength: 0)
                    if metrics.showCorner {
                        Text(verbatim: cornerLabel(ad: ad, bs: bs))
                            .font(.system(size: 8.5))
                            .monospacedDigit()
                            .foregroundStyle(minor)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.top, 2)
            }
            .overlay(alignment: .bottom) {
                if let p = panchang {
                    Text(verbatim: Formatter.tithiOnly(p.tithi, lang))
                        .font(lang == .english ? .system(size: 8.5).width(.condensed) : .system(size: 9))
                        .fontWeight(p.isPurnima || p.isAunsi ? .semibold : .regular)
                        .foregroundStyle(minor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.horizontal, 2)
                        .padding(.bottom, 3)
                }
            }
            .background { DayMark(isToday: isToday, isSelected: isSelected, isOtherToday: isOtherToday,
                                  isHovered: metrics.interactive && hovered.wrappedValue, accent: palette.accent) }
            .contentShape(Rectangle())
            .onHover { inside in if metrics.interactive { hovered.wrappedValue = inside } }
            .onTapGesture { onSelect?(jdn) }
            .help(helpText)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityText(ad: ad, weekday: weekday))
            .accessibilityAddTraits(isToday || isSelected ? [.isButton, .isSelected] : .isButton)
            .accessibilityAction { onSelect?(jdn) }
    }

    /// A red numeral already says "holiday", so the dot marks only what it can't: festivals, regional
    /// holidays, and a holiday on today's filled box, where the numeral isn't red.
    private func marker(isPublicHoliday: Bool) -> EventDot.Kind? {
        if isPublicHoliday { return isToday ? .publicHoliday : nil }
        if events.contains(where: { $0.category == .regionalHoliday }) { return .regionalHoliday }
        if events.contains(where: { $0.category == .festival }) { return .festival }
        return nil
    }

    /// The other calendar's day, with its month on the 1st.
    private func cornerLabel(ad: ADDate, bs: BSDate?) -> String {
        switch primary {
        case .bs:
            return ad.day == 1 ? Formatter.adShort(ad, .english) : "\(ad.day)"
        case .ad:
            guard let bs else { return "" }
            return bs.day == 1 ? Formatter.dateShort(bs, lang) : Formatter.digits(bs.day, lang)
        }
    }

    private var helpText: String {
        var lines: [String] = []
        if isToday { lines.append(lang == .nepali ? "नेपालमा आज" : "Today in Nepal") }
        if isOtherToday { lines.append(lang == .nepali ? "यहाँ आज" : "Today where you are") }
        lines += events.filter { $0.category != .observance }.map { $0.name(lang) }
        return lines.joined(separator: "\n")
    }

    private func accessibilityText(ad: ADDate, weekday: Int) -> String {
        guard let bs = BSDate(jdn: jdn) else { return "" }
        let bsText = Formatter.dateFull(bs, weekday: weekday, lang)
        var parts = primary == .bs ? [bsText, Formatter.adLong(ad, .english)] : [Formatter.adLong(ad, .english), bsText]
        if isToday { parts.insert(lang == .nepali ? "नेपालमा आज" : "Today in Nepal", at: 0) }
        if isOtherToday { parts.insert(lang == .nepali ? "यहाँ आज" : "Today where you are", at: 0) }
        parts += events.map { $0.isPublicHoliday ? "\($0.name(lang)), \(lang == .nepali ? "सार्वजनिक बिदा" : "public holiday")" : $0.name(lang) }
        return parts.joined(separator: ", ")
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

/// How a day is marked in any grid: its whole box. Filled with the accent for today, tinted for
/// the selection, outlined for today on the other clock.
public struct DayMark: View {
    let isToday: Bool
    let isSelected: Bool
    let isOtherToday: Bool
    let isHovered: Bool
    let accent: Color

    @Environment(\.colorSchemeContrast) private var contrast

    public init(isToday: Bool, isSelected: Bool, isOtherToday: Bool, isHovered: Bool = false, accent: Color) {
        self.isToday = isToday
        self.isSelected = isSelected
        self.isOtherToday = isOtherToday
        self.isHovered = isHovered
        self.accent = accent
    }

    public var body: some View {
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
}
