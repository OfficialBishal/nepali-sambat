import SambatCore
import SambatUI
import SwiftUI

struct ConverterPage: View {
    @Environment(AppModel.self) private var model
    // `@State` is a macro in the macOS 27 SDK that needs Xcode's macro plugin, so view state is
    // declared as plain `State` storage. Behaviour is identical.
    private var _copied = State<Bool>(initialValue: false)
    private var copied: Bool { get { _copied.wrappedValue } nonmutating set { _copied.wrappedValue = newValue } }

    var body: some View {
        @Bindable var model = model
        let jdn = resultJDN
        let other = model.settings.basis == .nepal ? model.localTodayJDN : model.nepalTodayJDN
        let s = model.settings
        let metrics = GridMetrics(showCorner: s.showAD, showTithi: s.showTithi)
        VStack(alignment: .leading, spacing: 14) {
            PillPicker(selection: $model.convertDirection, items: [
                .init(ConvertDirection.adToBS, model.t("AD to BS", "ईस्वीबाट विक्रम")),
                .init(ConvertDirection.bsToAD, model.t("BS to AD", "विक्रमबाट ईस्वी")),
            ])

            VStack(alignment: .leading, spacing: 10) {
                if model.convertDirection == .adToBS {
                    ADDatePicker(date: $model.convertAD)
                    let chosen = ADDate(jdn: JDN.of(model.convertAD, in: .current))
                    ADMonthGrid(year: chosen.year, month: chosen.month, todayJDN: model.todayJDN, otherTodayJDN: other,
                                selectedJDN: chosen.jdn, lang: model.cal, palette: model.palette, metrics: metrics) { jdn in
                        model.convertAD = JDN.startOfDay(jdn, in: .current).addingTimeInterval(12 * 3600)
                    }
                } else {
                    BSDatePicker(date: $model.convertBS, lang: model.cal)
                    MonthGrid(year: model.convertBS.year, month: model.convertBS.month,
                              todayJDN: model.todayJDN, otherTodayJDN: other, selectedJDN: model.convertBS.jdn,
                              lang: model.cal, palette: model.palette, metrics: metrics,
                              onSelect: { jdn in if let d = BSDate(jdn: jdn) { model.convertBS = d } })
                }
            }
            // Room for six rows, so the result below doesn't move between months.
            .frame(height: 36 + 15 + 6 * metrics.cellHeight, alignment: .top)
            .onChange(of: model.convertDirection) { copied = false }

            Divider()

            if let jdn {
                let p = Panchang.shared.day(jdn)
                var seen = Set<String>()
                let events = FestivalEngine.shared.events(on: jdn)
                    .filter { $0.category != .observance && seen.insert($0.nameEn).inserted }
                VStack(alignment: .leading, spacing: 3) {
                    Text(verbatim: primaryResult(jdn))
                        .font(.system(size: 20, weight: .semibold))
                        .textSelection(.enabled)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    HStack(alignment: .center, spacing: 2) {
                        Text(model.relative(jdn))
                            .font(.subheadline)
                            .foregroundStyle(.quiet)
                        Spacer(minLength: 6)
                        IconButton(symbol: copied ? "checkmark" : "doc.on.doc",
                                   label: copied ? model.t("Copied", "कपी भयो") : model.t("Copy date", "मिति कपी गर्नुहोस्")) {
                            Clipboard.copy(primaryResult(jdn))
                            copied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                        }
                        IconButton(symbol: "calendar", label: model.t("Show in Calendar", "पात्रोमा हेर्नुहोस्")) {
                            model.reveal(jdn)
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    FactRow(symbol: MoonIcon.name(for: p.tithi), text: Formatter.tithiShort(p, model.cal))
                    ForEach(events.prefix(2), id: \.id) { e in EventLine(event: e) }
                }
            }

            Spacer(minLength: 0)

            Text(model.t("Works for \(BSCalendar.firstYear)–\(BSCalendar.lastYear) BS (1918–2044 AD).",
                         "वि.सं. \(Formatter.digits(BSCalendar.firstYear, .nepali))–\(Formatter.digits(BSCalendar.lastYear, .nepali)) (सन् १९१८–२०४४) सम्म।"))
                .font(.caption)
                .foregroundStyle(.quiet)
        }
        .padding(16)
    }

    private var resultJDN: Int? {
        switch model.convertDirection {
        case .adToBS:
            let jdn = JDN.of(model.convertAD, in: .current)
            return BSDate(jdn: jdn) == nil ? nil : jdn
        case .bsToAD:
            return model.convertBS.jdn
        }
    }

    /// The converted date in its one long format, weekday first.
    private func primaryResult(_ jdn: Int) -> String {
        switch model.convertDirection {
        case .adToBS: return model.bsLong(jdn)
        case .bsToAD: return "\(Formatter.weekday(JDN.weekday(jdn), .english)), \(Formatter.adLong(ADDate(jdn: jdn), .english))" // "Monday, 16 November 2026"
        }
    }
}

/// Year, month and day pop-up buttons for a Bikram Sambat date.
struct BSDatePicker: View {
    @Binding var date: BSDate
    let lang: Language

    var body: some View {
        HStack(spacing: 6) {
            MenuField(title: lang == .nepali ? "दिन" : "Day", selection: $date.day,
                      options: (1...(BSCalendar.daysInMonth(year: date.year, month: date.month) ?? 30)).map { ($0, Formatter.digits($0, lang)) })
                .frame(width: 62)
            MenuField(title: lang == .nepali ? "महिना" : "Month", selection: monthBinding,
                      options: (1...12).map { ($0, Formatter.bsMonth($0, lang)) })
                .frame(width: 112)
            MenuField(title: lang == .nepali ? "साल" : "Year", selection: yearBinding,
                      options: (BSCalendar.firstYear...BSCalendar.lastYear).reversed().map { ($0, Formatter.digits($0, lang)) })
                .frame(width: 84)
            Spacer(minLength: 0)
        }
    }

    private var yearBinding: Binding<Int> {
        Binding(get: { date.year }, set: { date = clamped(year: $0, month: date.month, day: date.day) })
    }

    private var monthBinding: Binding<Int> {
        Binding(get: { date.month }, set: { date = clamped(year: date.year, month: $0, day: date.day) })
    }

    private func clamped(year: Int, month: Int, day: Int) -> BSDate {
        let len = BSCalendar.daysInMonth(year: year, month: month) ?? 30
        return BSDate(year: year, month: month, day: min(day, len))
    }
}

/// Year, month and day pop-up buttons for a Gregorian date, matching `BSDatePicker`.
struct ADDatePicker: View {
    @Binding var date: Date

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = .current
        return c
    }

    var body: some View {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        let year = parts.year ?? 2026, month = parts.month ?? 1, day = parts.day ?? 1
        let first = ADDate(jdn: BSCalendar.firstJDN).year, last = ADDate(jdn: BSCalendar.endJDN - 1).year
        HStack(spacing: 6) {
            MenuField(title: "Day", selection: Binding(get: { day }, set: { set(year: year, month: month, day: $0) }),
                      options: (1...ADDate.daysInMonth(year: year, month: month)).map { ($0, "\($0)") })
                .frame(width: 62)
            MenuField(title: "Month", selection: Binding(get: { month }, set: { set(year: year, month: $0, day: day) }),
                      options: (1...12).map { ($0, Formatter.adMonth($0, .english)) })
                .frame(width: 112)
            MenuField(title: "Year", selection: Binding(get: { year }, set: { set(year: $0, month: month, day: day) }),
                      options: (first...last).reversed().map { ($0, "\($0)") })
                .frame(width: 84)
            Spacer(minLength: 0)
        }
    }

    private func set(year: Int, month: Int, day: Int) {
        let d = min(day, ADDate.daysInMonth(year: year, month: month))
        let jdn = min(max(ADDate(year: year, month: month, day: d).jdn, BSCalendar.firstJDN), BSCalendar.endJDN - 1)
        date = JDN.startOfDay(jdn, in: .current).addingTimeInterval(12 * 3600)
    }
}
