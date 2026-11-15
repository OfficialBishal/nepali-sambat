import PatroCore
import SwiftUI

/// A Bikram Sambat month laid out Sunday-first, as in a printed patro.
public struct MonthGrid: View {
    public struct Metrics: Sendable {
        public var cellHeight: CGFloat
        public var numeralSize: CGFloat
        public var circle: CGFloat
        public var showAD: Bool
        public var showTithi: Bool
        public var interactive: Bool

        public init(cellHeight: CGFloat = 44, numeralSize: CGFloat = 15, circle: CGFloat = 26,
                    showAD: Bool = true, showTithi: Bool = true, interactive: Bool = true) {
            self.cellHeight = cellHeight
            self.numeralSize = numeralSize
            self.circle = circle
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
        let rows = (lead + length + 6) / 7
        let events = FestivalEngine.shared.eventsByDay(year: year, month: month)

        Grid(horizontalSpacing: 0, verticalSpacing: 0) {
            GridRow {
                ForEach(0..<7, id: \.self) { wd in
                    Text(Formatter.weekday(wd, lang, short: true))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(wd == 6 ? AnyShapeStyle(Palette.holiday) : AnyShapeStyle(.secondary))
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 4)
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
                                    lang: lang, palette: palette, metrics: metrics, onSelect: onSelect)
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
        let hasRegionalHoliday = events.contains { $0.category == .regionalHoliday }
        let hasFestival = !events.isEmpty && !events.allSatisfy { $0.isPublicHoliday }
        let panchang = metrics.showTithi ? Panchang.shared.day(jdn) : nil

        VStack(spacing: 1) {
            ZStack {
                if isToday {
                    Circle().fill(palette.accent)
                } else if isSelected {
                    Circle().fill(Color.primary.opacity(contrast == .increased ? 0.2 : 0.1))
                } else if isOtherToday {
                    Circle().strokeBorder(.secondary, lineWidth: 1)
                }
                Text(Formatter.digits(day, lang))
                    .font(.system(size: metrics.numeralSize, weight: isToday ? .semibold : .regular))
                    .foregroundStyle(numeralStyle(isHoliday: isHoliday))
            }
            .frame(width: metrics.circle, height: metrics.circle)

            if panchang != nil || hasFestival || hasRegionalHoliday {
                HStack(spacing: 2) {
                    if hasFestival || hasRegionalHoliday {
                        Circle()
                            .fill(hasRegionalHoliday ? AnyShapeStyle(Palette.holiday) : AnyShapeStyle(.secondary))
                            .frame(width: 3.5, height: 3.5)
                    }
                    if let p = panchang {
                        Text(tithiLabel(p))
                            .font(.system(size: 8, weight: p.isPurnima || p.isAunsi ? .semibold : .regular))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                }
                .frame(height: 10)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: metrics.cellHeight)
        .overlay(alignment: .topTrailing) {
            if metrics.showAD {
                Text(ad.day == 1 ? Formatter.adShort(ad, .english) : "\(ad.day)")
                    .font(.system(size: 8.5))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .padding(.top, 1)
                    .padding(.trailing, 3)
            }
        }
        .background {
            if metrics.interactive && hovered.wrappedValue && !isToday {
                RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.primary.opacity(0.05))
            }
        }
        .contentShape(Rectangle())
        .onHover { inside in if metrics.interactive { hovered.wrappedValue = inside } }
        .onTapGesture { onSelect?(jdn) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText(ad: ad, weekday: weekday))
        .accessibilityAddTraits(isToday || isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { onSelect?(jdn) }
    }

    private func numeralStyle(isHoliday: Bool) -> AnyShapeStyle {
        if isToday { return AnyShapeStyle(palette.onAccent) }
        return isHoliday ? AnyShapeStyle(Palette.holiday) : AnyShapeStyle(.primary)
    }

    private func tithiLabel(_ p: DayPanchang) -> String {
        Formatter.tithiOnly(p.tithi, lang)
    }

    private func accessibilityText(ad: ADDate, weekday: Int) -> String {
        guard let bs = BSDate(jdn: jdn) else { return "" }
        var parts = ["\(Formatter.dateLong(bs, lang)), \(Formatter.weekday(weekday, lang))", Formatter.adLong(ad, .english)]
        if isToday { parts.insert(lang == .nepali ? "आज" : "Today", at: 0) }
        parts += events.map { $0.isPublicHoliday ? "\($0.name(lang)), \(lang == .nepali ? "सार्वजनिक बिदा" : "public holiday")" : $0.name(lang) }
        return parts.joined(separator: ", ")
    }
}
