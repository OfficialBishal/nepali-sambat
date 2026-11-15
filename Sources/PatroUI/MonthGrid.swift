import SwiftUI
import PatroCore

/// A Bikram Sambat month laid out Sunday-first, as in a printed patro.
public struct MonthGrid: View {
    public struct Metrics: Sendable {
        public var cellHeight: CGFloat
        public var dayFont: CGFloat
        public var smallFont: CGFloat
        public var spacing: CGFloat
        public var showAD: Bool
        public var showTithi: Bool

        public init(cellHeight: CGFloat = 44, dayFont: CGFloat = 16, smallFont: CGFloat = 8.5,
                    spacing: CGFloat = 2, showAD: Bool = true, showTithi: Bool = true) {
            self.cellHeight = cellHeight
            self.dayFont = dayFont
            self.smallFont = smallFont
            self.spacing = spacing
            self.showAD = showAD
            self.showTithi = showTithi
        }
    }

    let year: Int
    let month: Int
    let todayJDN: Int
    let localTodayJDN: Int?
    let selectedJDN: Int?
    let lang: Language
    let theme: Theme
    let metrics: Metrics
    let onSelect: ((Int) -> Void)?

    public init(year: Int, month: Int, todayJDN: Int, localTodayJDN: Int? = nil, selectedJDN: Int? = nil,
                lang: Language, theme: Theme, metrics: Metrics = Metrics(), onSelect: ((Int) -> Void)? = nil) {
        self.year = year
        self.month = month
        self.todayJDN = todayJDN
        self.localTodayJDN = localTodayJDN
        self.selectedJDN = selectedJDN
        self.lang = lang
        self.theme = theme
        self.metrics = metrics
        self.onSelect = onSelect
    }

    public var body: some View {
        let start = BSCalendar.startJDN(year: year, month: month) ?? 0
        let length = BSCalendar.daysInMonth(year: year, month: month) ?? 30
        let lead = JDN.weekday(start)
        let rows = (lead + length + 6) / 7
        let events = FestivalEngine.shared.eventsByDay(year: year, month: month)

        VStack(spacing: metrics.spacing) {
            HStack(spacing: metrics.spacing) {
                ForEach(0..<7, id: \.self) { wd in
                    Text(Formatter.weekday(wd, lang, short: true))
                        .font(.system(size: metrics.smallFont + 1.5, weight: .semibold))
                        .foregroundStyle(wd == 6 ? theme.holiday : theme.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 2)
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: metrics.spacing) {
                    ForEach(0..<7, id: \.self) { col in
                        let index = row * 7 + col - lead
                        if index >= 0 && index < length {
                            let jdn = start + index
                            DayCell(jdn: jdn, day: index + 1, events: events[jdn] ?? [],
                                    isToday: jdn == todayJDN,
                                    isLocalToday: localTodayJDN == jdn && localTodayJDN != todayJDN,
                                    isSelected: jdn == selectedJDN,
                                    lang: lang, theme: theme, metrics: metrics, onSelect: onSelect)
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
    let isLocalToday: Bool
    let isSelected: Bool
    let lang: Language
    let theme: Theme
    let metrics: MonthGrid.Metrics
    let onSelect: ((Int) -> Void)?

    var body: some View {
        let ad = ADDate(jdn: jdn)
        let saturday = JDN.weekday(jdn) == 6
        let holiday = saturday || events.contains { $0.isPublicHoliday }
        let panchang = metrics.showTithi ? Panchang.shared.day(jdn) : nil
        let hasFestival = events.contains { !$0.isPublicHoliday }
        let numberColor: Color = isSelected ? theme.onAccent : (holiday ? theme.holiday : theme.primary)
        let small: Color = isSelected ? theme.onAccent.opacity(0.85) : theme.secondary

        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? theme.accent : (isToday ? theme.accent.opacity(0.13) : Color.clear))
            if isToday && !isSelected {
                RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(theme.accent, lineWidth: 1.5)
            }
            if isLocalToday && !isSelected {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(theme.secondary.opacity(0.7), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
            }
            VStack(spacing: 0) {
                if metrics.showAD {
                    HStack {
                        Spacer(minLength: 0)
                        Text(ad.day == 1 ? Formatter.adShort(ad, .english) : "\(ad.day)")
                            .font(.system(size: metrics.smallFont, weight: .medium))
                            .foregroundStyle(small)
                            .lineLimit(1)
                    }
                    .padding(.trailing, 4)
                    .padding(.top, 2)
                }
                Spacer(minLength: 0)
                Text(Formatter.digits(day, lang))
                    .font(.system(size: metrics.dayFont, weight: .semibold, design: .rounded))
                    .foregroundStyle(numberColor)
                Spacer(minLength: 0)
                if let p = panchang {
                    Text(tithiLabel(p))
                        .font(.system(size: metrics.smallFont - 0.5, weight: p.isPurnima || p.isAunsi ? .bold : .regular))
                        .foregroundStyle(small)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 2)
                        .padding(.bottom, 2)
                }
            }
            if hasFestival {
                VStack {
                    HStack {
                        Circle().fill(isSelected ? theme.onAccent : theme.festival).frame(width: 4.5, height: 4.5)
                        Spacer()
                    }
                    Spacer()
                }
                .padding(5)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: metrics.cellHeight)
        .contentShape(Rectangle())
        .onTapGesture { onSelect?(jdn) }
        .help(helpText(ad: ad))
    }

    private func tithiLabel(_ p: DayPanchang) -> String {
        if p.isPurnima { return lang == .nepali ? "पूर्णिमा" : "Purnima" }
        if p.isAunsi { return lang == .nepali ? "औंसी" : "Aunsi" }
        return Formatter.tithiOnly(p.tithi, lang)
    }

    private func helpText(ad: ADDate) -> String {
        var parts = [Formatter.adLong(ad, .english)]
        parts += events.map { $0.name(lang) }
        return parts.joined(separator: "\n")
    }
}
