import PatroCore
import PatroUI
import SwiftUI

struct ConverterPage: View {
    @Environment(AppModel.self) private var model
    // `@State` is a macro in the macOS 27 SDK that needs Xcode's macro plugin, so view state is
    // declared as plain `State` storage throughout. Behaviour is identical.
    private var _adDate = State<Date>(initialValue: Date())
    private var adDate: Date { get { _adDate.wrappedValue } nonmutating set { _adDate.wrappedValue = newValue } }
    private var _bsYear = State<Int>(initialValue: 2083)
    private var bsYear: Int { get { _bsYear.wrappedValue } nonmutating set { _bsYear.wrappedValue = newValue } }
    private var _bsMonth = State<Int>(initialValue: 1)
    private var bsMonth: Int { get { _bsMonth.wrappedValue } nonmutating set { _bsMonth.wrappedValue = newValue } }
    private var _bsDay = State<Int>(initialValue: 1)
    private var bsDay: Int { get { _bsDay.wrappedValue } nonmutating set { _bsDay.wrappedValue = newValue } }
    private var _didInit = State<Bool>(initialValue: false)
    private var didInit: Bool { get { _didInit.wrappedValue } nonmutating set { _didInit.wrappedValue = newValue } }
    private var _copied = State<String?>(initialValue: nil)
    private var copied: String? { get { _copied.wrappedValue } nonmutating set { _copied.wrappedValue = newValue } }

    private var adRange: ClosedRange<Date> {
        let lo = JDN.startOfDay(BSCalendar.firstJDN, in: .current)
        let hi = JDN.startOfDay(BSCalendar.endJDN - 1, in: .current)
        return lo...hi
    }

    var body: some View {
        let theme = model.theme
        let lang = model.lang
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 12) {
                PageTitle(text: model.t("Date Converter", "मिति रूपान्तरण"))

                Card {
                    SectionLabel(text: model.t("English (AD) → Nepali (BS)", "ईस्वी (AD) → विक्रम सम्वत् (BS)"))
                    HStack {
                        DatePicker("", selection: _adDate.projectedValue, in: adRange, displayedComponents: .date)
                            .datePickerStyle(.stepperField)
                            .labelsHidden()
                        Spacer()
                        PillButton(title: model.t("Today", "आज")) { adDate = Date() }
                    }
                    let jdn = JDN.of(adDate, in: .current)
                    if let bs = BSDate(jdn: jdn) {
                        result(primary: Formatter.dateLong(bs, lang),
                               secondary: "\(Formatter.weekday(JDN.weekday(jdn), lang)) · \(Formatter.tithiName(Panchang.shared.day(jdn), lang))",
                               jdn: jdn,
                               copyText: "\(Formatter.dateLong(bs, lang)), \(Formatter.weekday(JDN.weekday(jdn), lang))",
                               key: "ad")
                    }
                }

                Card {
                    SectionLabel(text: model.t("Nepali (BS) → English (AD)", "विक्रम सम्वत् (BS) → ईस्वी (AD)"))
                    HStack(spacing: 6) {
                        Picker("", selection: _bsYear.projectedValue) {
                            ForEach((BSCalendar.firstYear...BSCalendar.lastYear).reversed(), id: \.self) { y in
                                Text(Formatter.digits(y, lang)).tag(y)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 80)
                        Picker("", selection: _bsMonth.projectedValue) {
                            ForEach(1...12, id: \.self) { m in Text(Formatter.bsMonth(m, lang)).tag(m) }
                        }
                        .labelsHidden()
                        .frame(width: 100)
                        Picker("", selection: _bsDay.projectedValue) {
                            ForEach(1...(BSCalendar.daysInMonth(year: bsYear, month: bsMonth) ?? 30), id: \.self) { d in
                                Text(Formatter.digits(d, lang)).tag(d)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 66)
                    }
                    .pickerStyle(.menu)
                    if let jdn = BSDate(year: bsYear, month: bsMonth, day: bsDay).jdn {
                        let ad = ADDate(jdn: jdn)
                        result(primary: Formatter.adLong(ad, .english),
                               secondary: "\(Formatter.weekday(JDN.weekday(jdn), .english)) · \(Formatter.tithiName(Panchang.shared.day(jdn), lang))",
                               jdn: jdn,
                               copyText: "\(Formatter.weekday(JDN.weekday(jdn), .english)), \(Formatter.adLong(ad, .english))",
                               key: "bs")
                    }
                }

                Card {
                    SectionLabel(text: model.t("Good to know", "थाहा पाउनुहोस्"))
                    Text(model.t("Supported range: \(BSCalendar.firstYear)–\(BSCalendar.lastYear) BS (1918–2044 AD). Tithi is computed for sunrise in Kathmandu.",
                                 "समर्थित अवधि: वि.सं. \(Formatter.digits(BSCalendar.firstYear, lang))–\(Formatter.digits(BSCalendar.lastYear, lang))। तिथि काठमाडौंको सूर्योदयअनुसार गणना गरिएको।"))
                        .font(.system(size: 10.5))
                        .foregroundStyle(theme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(12)
        }
        .onAppear {
            guard !didInit else { return }
            didInit = true
            let t = model.today
            bsYear = t.year
            bsMonth = t.month
            bsDay = t.day
        }
        .onChange(of: bsYear) { clampDay() }
        .onChange(of: bsMonth) { clampDay() }
    }

    private func clampDay() {
        let len = BSCalendar.daysInMonth(year: bsYear, month: bsMonth) ?? 30
        if bsDay > len { bsDay = len }
    }

    @ViewBuilder
    private func result(primary: String, secondary: String, jdn: Int, copyText: String, key: String) -> some View {
        let theme = model.theme
        VStack(alignment: .leading, spacing: 3) {
            Text(primary).font(.system(size: 19, weight: .bold, design: .rounded)).textSelection(.enabled)
            Text(secondary).font(.system(size: 11)).foregroundStyle(theme.secondary)
            HStack(spacing: 6) {
                Text(Formatter.relativeDays(jdn - model.todayJDN, model.lang))
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(theme.secondary)
                Spacer()
                PillButton(title: copied == key ? model.t("Copied", "कपी भयो") : model.t("Copy", "कपी"),
                           systemImage: copied == key ? "checkmark" : "doc.on.doc") {
                    Clipboard.copy(copyText)
                    copied = key
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { if copied == key { copied = nil } }
                }
                PillButton(title: model.t("Show", "हेर्नुहोस्"), systemImage: "calendar", prominent: true) {
                    model.showMonth(of: jdn)
                    model.select(jdn)
                    model.page = .calendar
                }
            }
        }
        .padding(.top, 2)
    }
}
