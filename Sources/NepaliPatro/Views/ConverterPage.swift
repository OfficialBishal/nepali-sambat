import PatroCore
import PatroUI
import SwiftUI

struct ConverterPage: View {
    @Environment(AppModel.self) private var model
    // `@State` is a macro in the macOS 27 SDK that needs Xcode's macro plugin, so view state is
    // declared as plain `State` storage. Behaviour is identical.
    private var _copied = State<Bool>(initialValue: false)
    private var copied: Bool { get { _copied.wrappedValue } nonmutating set { _copied.wrappedValue = newValue } }

    private var adRange: ClosedRange<Date> {
        JDN.startOfDay(BSCalendar.firstJDN, in: .current)...JDN.startOfDay(BSCalendar.endJDN - 1, in: .current)
    }

    var body: some View {
        @Bindable var model = model
        let jdn = resultJDN
        VStack(alignment: .leading, spacing: 14) {
            Text(model.t("Convert a date", "मिति रूपान्तरण"))
                .font(.title3.weight(.semibold))

            Picker("", selection: $model.convertDirection) {
                Text(model.t("English to Nepali", "ईस्वीबाट विक्रम")).tag(ConvertDirection.adToBS)
                Text(model.t("Nepali to English", "विक्रमबाट ईस्वी")).tag(ConvertDirection.bsToAD)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            VStack(alignment: .leading, spacing: 10) {
                if model.convertDirection == .adToBS {
                    HStack(spacing: 8) {
                        DatePicker(model.t("Date", "मिति"), selection: $model.convertAD, in: adRange, displayedComponents: .date)
                            .datePickerStyle(.stepperField)
                            .fixedSize()
                        Spacer(minLength: 0)
                        ControlGroup {
                            Button { stepAD(months: -1) } label: { Image(systemName: "chevron.left") }
                                .accessibilityLabel(model.t("Previous month", "अघिल्लो महिना"))
                            Button { stepAD(months: 1) } label: { Image(systemName: "chevron.right") }
                                .accessibilityLabel(model.t("Next month", "अर्को महिना"))
                        }
                        .controlSize(.small)
                        .fixedSize()
                    }
                    ADMonthGrid(selected: JDN.of(model.convertAD, in: .current), todayJDN: model.localTodayJDN,
                                palette: model.palette) { jdn in
                        model.convertAD = JDN.startOfDay(jdn, in: .current).addingTimeInterval(12 * 3600)
                    }
                } else {
                    BSDatePicker(date: $model.convertBS, lang: model.cal)
                    MonthGrid(year: model.convertBS.year, month: model.convertBS.month,
                              todayJDN: model.todayJDN, selectedJDN: model.convertBS.jdn,
                              lang: model.cal, palette: model.palette,
                              metrics: .init(cellHeight: 25, numeralSize: 12.5, circle: 21, showAD: false, showTithi: false),
                              onSelect: { jdn in if let d = BSDate(jdn: jdn) { model.convertBS = d } })
                }
            }
            .frame(height: 214, alignment: .top)
            .onChange(of: model.convertDirection) { copied = false }

            Divider()

            if let jdn {
                let p = Panchang.shared.day(jdn)
                VStack(alignment: .leading, spacing: 4) {
                    Text(primaryResult(jdn))
                        .font(.system(size: 24, weight: .semibold))
                        .textSelection(.enabled)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(secondaryResult(jdn))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 5) {
                        Image(systemName: MoonIcon.name(for: p.tithi)).font(.system(size: 10))
                        Text(Formatter.tithiName(p, model.cal))
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    Text(Formatter.relativeDays(jdn - model.todayJDN, model.lang))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }
                HStack(spacing: 8) {
                    Button {
                        Clipboard.copy(copyText(jdn))
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                    } label: {
                        Label(copied ? model.t("Copied", "कपी भयो") : model.t("Copy", "कपी"),
                              systemImage: copied ? "checkmark" : "doc.on.doc")
                    }
                    Button(model.t("Show in Calendar", "पात्रोमा हेर्नुहोस्")) {
                        model.showMonth(of: jdn)
                        model.select(jdn)
                        model.page = .calendar
                    }
                }
                .controlSize(.small)
            }

            Spacer(minLength: 0)

            Text(model.t("Works for \(BSCalendar.firstYear)–\(BSCalendar.lastYear) BS (1918–2044 AD).",
                         "वि.सं. \(Formatter.digits(BSCalendar.firstYear, .nepali))–\(Formatter.digits(BSCalendar.lastYear, .nepali)) (सन् १९१८–२०४४) सम्म।"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
    }

    private func stepAD(months n: Int) {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        guard let next = cal.date(byAdding: .month, value: n, to: model.convertAD) else { return }
        model.convertAD = min(max(next, adRange.lowerBound), adRange.upperBound)
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

    private func primaryResult(_ jdn: Int) -> String {
        switch model.convertDirection {
        case .adToBS: return BSDate(jdn: jdn).map { Formatter.dateLong($0, model.cal) } ?? ""
        case .bsToAD: return Formatter.adLong(ADDate(jdn: jdn), .english)
        }
    }

    private func secondaryResult(_ jdn: Int) -> String {
        switch model.convertDirection {
        case .adToBS: return Formatter.weekday(JDN.weekday(jdn), model.cal)
        case .bsToAD: return Formatter.weekday(JDN.weekday(jdn), .english)
        }
    }

    private func copyText(_ jdn: Int) -> String {
        "\(primaryResult(jdn)), \(secondaryResult(jdn))"
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

/// A Gregorian month in the same visual language as the patro grid, for picking an AD date.
struct ADMonthGrid: View {
    let selected: Int
    let todayJDN: Int
    let palette: Palette
    let onSelect: (Int) -> Void

    var body: some View {
        let ad = ADDate(jdn: selected)
        let start = JDN.from(year: ad.year, month: ad.month, day: 1)
        let length = ADDate.daysInMonth(year: ad.year, month: ad.month)
        let lead = JDN.weekday(start)
        let rows = (lead + length + 6) / 7
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: "\(Formatter.adMonth(ad.month, .english)) \(ad.year)")
                .font(.subheadline.weight(.semibold))
                .padding(.leading, 6)
            Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                GridRow {
                    ForEach(0..<7, id: \.self) { wd in
                        Text(Formatter.weekday(wd, .english, short: true))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.bottom, 3)
                    }
                }
                ForEach(0..<rows, id: \.self) { row in
                    GridRow {
                        ForEach(0..<7, id: \.self) { col in
                            let index = row * 7 + col - lead
                            if index >= 0 && index < length {
                                let jdn = start + index
                                let isSelected = jdn == selected
                                let isToday = jdn == todayJDN
                                ZStack {
                                    if isSelected {
                                        Circle().fill(palette.accent)
                                    } else if isToday {
                                        Circle().strokeBorder(palette.accent, lineWidth: 1)
                                    }
                                    Text("\(index + 1)")
                                        .font(.system(size: 12.5, weight: isSelected ? .semibold : .regular))
                                        .monospacedDigit()
                                        .foregroundStyle(isSelected ? AnyShapeStyle(palette.onAccent) : AnyShapeStyle(.primary))
                                }
                                .frame(width: 21, height: 21)
                                .frame(maxWidth: .infinity)
                                .frame(height: 25)
                                .contentShape(Rectangle())
                                .onTapGesture { onSelect(jdn) }
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel(Formatter.adLong(ADDate(jdn: jdn), .english))
                                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                            } else {
                                Color.clear.frame(maxWidth: .infinity).frame(height: 25)
                            }
                        }
                    }
                }
            }
        }
    }
}
