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
        VStack(alignment: .leading, spacing: 14) {
            Text(model.t("Convert a date", "मिति रूपान्तरण"))
                .font(.title3.weight(.semibold))

            PillPicker(selection: $model.convertDirection, items: [
                (ConvertDirection.adToBS, model.t("AD to BS", "ईस्वीबाट विक्रम")),
                (ConvertDirection.bsToAD, model.t("BS to AD", "विक्रमबाट ईस्वी")),
            ])

            VStack(alignment: .leading, spacing: 10) {
                if model.convertDirection == .adToBS {
                    ADDatePicker(date: $model.convertAD)
                    ADMonthGrid(selected: JDN.of(model.convertAD, in: .current), todayJDN: model.todayJDN,
                                otherTodayJDN: other, palette: model.palette) { jdn in
                        model.convertAD = JDN.startOfDay(jdn, in: .current).addingTimeInterval(12 * 3600)
                    }
                } else {
                    BSDatePicker(date: $model.convertBS, lang: model.cal)
                    MonthGrid(year: model.convertBS.year, month: model.convertBS.month,
                              todayJDN: model.todayJDN, otherTodayJDN: other, selectedJDN: model.convertBS.jdn,
                              lang: model.cal, palette: model.palette,
                              metrics: .init(cellHeight: 25, numeralSize: 12.5, numeralRow: 21, numeralTop: 2,
                                             showAD: false, showTithi: false),
                              onSelect: { jdn in if let d = BSDate(jdn: jdn) { model.convertBS = d } })
                }
            }
            .frame(height: 206, alignment: .top)
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
                    Text(model.relative(jdn))
                        .font(.subheadline)
                        .foregroundStyle(.quiet)
                }
                VStack(alignment: .leading, spacing: 6) {
                    FactRow(symbol: MoonIcon.name(for: p.tithi), text: Formatter.tithiShort(p, model.cal))
                    ForEach(events.prefix(2), id: \.id) { e in EventLine(event: e) }
                }
                HStack(spacing: 8) {
                    Button {
                        Clipboard.copy(primaryResult(jdn))
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                    } label: {
                        Label(copied ? model.t("Copied", "कपी भयो") : model.t("Copy", "कपी"),
                              systemImage: copied ? "checkmark" : "doc.on.doc")
                    }
                    Button { model.reveal(jdn) } label: {
                        Label(model.t("Show in Calendar", "पात्रोमा हेर्नुहोस्"), systemImage: "calendar")
                    }
                }
                .controlSize(.small)
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
            Picker("", selection: yearBinding) {
                ForEach((BSCalendar.firstYear...BSCalendar.lastYear).reversed(), id: \.self) { y in
                    Text(Formatter.digits(y, lang)).tag(y)
                }
            }
            .frame(width: 78)
            Picker("", selection: monthBinding) {
                ForEach(1...12, id: \.self) { m in Text(Formatter.bsMonth(m, lang)).tag(m) }
            }
            .frame(width: 96)
            Picker("", selection: $date.day) {
                ForEach(1...(BSCalendar.daysInMonth(year: date.year, month: date.month) ?? 30), id: \.self) { d in
                    Text(Formatter.digits(d, lang)).tag(d)
                }
            }
            .frame(width: 62)
            Spacer(minLength: 0)
        }
        .labelsHidden()
        .pickerStyle(.menu)
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
            Picker("", selection: Binding(get: { year }, set: { set(year: $0, month: month, day: day) })) {
                ForEach((first...last).reversed(), id: \.self) { y in Text(verbatim: "\(y)").tag(y) }
            }
            .frame(width: 78)
            Picker("", selection: Binding(get: { month }, set: { set(year: year, month: $0, day: day) })) {
                ForEach(1...12, id: \.self) { m in Text(Formatter.adMonth(m, .english)).tag(m) }
            }
            .frame(width: 112)
            Picker("", selection: Binding(get: { day }, set: { set(year: year, month: month, day: $0) })) {
                ForEach(1...ADDate.daysInMonth(year: year, month: month), id: \.self) { d in Text(verbatim: "\(d)").tag(d) }
            }
            .frame(width: 62)
            Spacer(minLength: 0)
        }
        .labelsHidden()
        .pickerStyle(.menu)
    }

    private func set(year: Int, month: Int, day: Int) {
        let d = min(day, ADDate.daysInMonth(year: year, month: month))
        let jdn = min(max(ADDate(year: year, month: month, day: d).jdn, BSCalendar.firstJDN), BSCalendar.endJDN - 1)
        date = JDN.startOfDay(jdn, in: .current).addingTimeInterval(12 * 3600)
    }
}

/// A Gregorian month drawn like the Nepali grid: today's cell in the accent, the chosen day tinted,
/// and today on the other clock outlined. Always six rows, so the result below never moves.
struct ADMonthGrid: View {
    let selected: Int
    let todayJDN: Int
    var otherTodayJDN: Int? = nil
    let palette: Palette
    let onSelect: (Int) -> Void

    var body: some View {
        let ad = ADDate(jdn: selected)
        let start = JDN.from(year: ad.year, month: ad.month, day: 1)
        let length = ADDate.daysInMonth(year: ad.year, month: ad.month)
        let lead = JDN.weekday(start)
        Grid(horizontalSpacing: 0, verticalSpacing: 0) {
            GridRow {
                ForEach(0..<7, id: \.self) { wd in
                    Text(Formatter.weekday(wd, .english, short: true))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(wd == 6 ? AnyShapeStyle(Palette.holiday) : AnyShapeStyle(.quiet))
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 4)
                        .accessibilityHidden(true)
                }
            }
            ForEach(0..<6, id: \.self) { row in
                GridRow {
                    ForEach(0..<7, id: \.self) { col in
                        let index = row * 7 + col - lead
                        if index >= 0 && index < length {
                            cell(jdn: start + index, day: index + 1)
                        } else {
                            Color.clear.frame(maxWidth: .infinity).frame(height: 25)
                        }
                    }
                }
            }
        }
    }

    private func cell(jdn: Int, day: Int) -> some View {
        let isSelected = jdn == selected && jdn != todayJDN
        let isToday = jdn == todayJDN
        let isOther = jdn == otherTodayJDN && otherTodayJDN != todayJDN
        return Text(verbatim: "\(day)")
            .font(.system(size: 12.5, weight: isToday ? .semibold : .regular))
            .monospacedDigit()
            .foregroundStyle(isToday ? AnyShapeStyle(palette.onAccent) : AnyShapeStyle(.primary))
            .frame(maxWidth: .infinity)
            .frame(height: 25)
            .background { DayMark(isToday: isToday, isSelected: isSelected, isOtherToday: isOther, accent: palette.accent) }
        .contentShape(Rectangle())
        .onTapGesture { onSelect(jdn) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Formatter.adLong(ADDate(jdn: jdn), .english))
        .accessibilityAddTraits(jdn == selected ? [.isButton, .isSelected] : .isButton)
    }
}
