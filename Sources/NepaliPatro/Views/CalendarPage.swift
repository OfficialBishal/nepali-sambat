import EventKit
import PatroCore
import PatroUI
import SwiftUI

struct CalendarPage: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let s = model.settings
        let rows = MonthGrid.rows(year: model.displayYear, month: model.displayMonth)
        VStack(alignment: .leading, spacing: 0) {
            TodayHeader()
                .padding(.horizontal, 16)
                .padding(.top, 14)
            DayDifferenceNote()
                .padding(.horizontal, 16)
                .padding(.top, 8)
            MonthBar()
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 6)
            MonthGrid(year: model.displayYear, month: model.displayMonth,
                      todayJDN: model.todayJDN,
                      otherTodayJDN: s.basis == .nepal ? model.localTodayJDN : model.nepalTodayJDN,
                      selectedJDN: model.selectedJDN,
                      lang: model.cal, palette: model.palette,
                      metrics: .init(cellHeight: rows == 6 ? 39 : 44, circle: rows == 6 ? 24 : 26,
                                     showAD: s.showAD, showTithi: s.showTithi),
                      onSelect: { model.select($0) })
                .padding(.horizontal, 10)
                .id(model.displayYear * 12 + model.displayMonth)
                .transition(monthTransition)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: model.displayYear * 12 + model.displayMonth)
            Divider()
                .padding(.horizontal, 16)
                .padding(.top, 4)
            DayDetail(jdn: model.focusJDN)
        }
        .clipped()
    }

    private var monthTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        let forward = model.monthStep >= 0
        return .asymmetric(insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                           removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity))
    }
}

struct TodayHeader: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let cal = model.cal
        let jdn = model.todayJDN
        let today = model.today
        let p = Panchang.shared.day(jdn)
        let showClock = NepalTime.offsetSeconds(from: .current, at: model.now) != 0

        HStack(alignment: .firstTextBaseline, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(verbatim: "\(Formatter.bsMonth(today.month, cal)) \(Formatter.digits(today.day, cal))")
                        .font(.system(size: 22, weight: .semibold))
                    Text(Formatter.digits(today.year, cal))
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(.secondary)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                Text(verbatim: "\(Formatter.weekday(JDN.weekday(jdn), cal)), \(Formatter.adLong(ADDate(jdn: jdn), .english))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 5) {
                    Image(systemName: MoonIcon.name(for: p.tithi)).font(.system(size: 10))
                    Text(Formatter.tithiName(p, cal))
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            .accessibilityElement(children: .combine)

            Spacer(minLength: 0)

            if showClock {
                VStack(alignment: .trailing, spacing: 3) {
                    Text(Formatter.time(model.now, in: NepalTime.timeZone, model.lang))
                        .font(.system(size: 17, weight: .medium))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text(model.t("in Nepal", "नेपालमा"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

/// Shown when Nepal and this Mac are on different dates: the moment the old app got wrong.
struct DayDifferenceNote: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let nepal = model.nepalTodayJDN
        let local = model.localTodayJDN
        if nepal != local {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: "clock")
                    .font(.system(size: 11))
                    .foregroundStyle(model.palette.accent)
                Text(message(nepal: nepal, local: local))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
        }
    }

    private func message(nepal: Int, local: Int) -> String {
        let ui = model.lang
        let localDay = Formatter.weekday(JDN.weekday(local), ui)
        let localDate = Formatter.adShort(ADDate(jdn: local), .english)
        let nepalDay = Formatter.weekday(JDN.weekday(nepal), ui)
        switch model.settings.basis {
        case .nepal where nepal > local:
            return model.t("Nepal is already on \(nepalDay). It’s still \(localDay), \(localDate) here.",
                           "नेपालमा \(nepalDay) सुरु भइसक्यो। यहाँ अझै \(localDay), \(localDate) हो।")
        case .nepal:
            return model.t("Nepal is still on \(nepalDay). It’s already \(localDay), \(localDate) here.",
                           "नेपालमा अझै \(nepalDay) हो। यहाँ \(localDay), \(localDate) भइसक्यो।")
        case .local:
            let bs = BSDate(jdn: nepal).map { Formatter.dateLong($0, model.cal) } ?? ""
            return model.t("In Nepal it’s already \(nepalDay), \(bs).", "नेपालमा आज \(nepalDay), \(bs) हो।")
        }
    }
}

struct MonthBar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let cal = model.cal
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Menu {
                    ForEach(1...12, id: \.self) { m in
                        Button(Formatter.bsMonth(m, cal)) { jump(year: model.displayYear, month: m) }
                    }
                    Divider()
                    Menu(model.t("Year", "साल")) {
                        ForEach((BSCalendar.firstYear...BSCalendar.lastYear).reversed(), id: \.self) { y in
                            Button(Formatter.digits(y, cal)) { jump(year: y, month: model.displayMonth) }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(verbatim: "\(Formatter.bsMonth(model.displayMonth, cal)) \(Formatter.digits(model.displayYear, cal))")
                            .font(.headline)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .menuIndicator(.hidden)
                .fixedSize()
                .help(model.t("Jump to a month or year", "महिना वा साल छान्नुहोस्"))
                Text(adRange)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            ControlGroup {
                Button { model.step(months: -1) } label: { Image(systemName: "chevron.left") }
                    .help(model.t("Previous month (←)", "अघिल्लो महिना (←)"))
                    .accessibilityLabel(model.t("Previous month", "अघिल्लो महिना"))
                Button(model.t("Today", "आज")) { model.goToToday() }
                    .help(model.t("Go to today (T)", "आजको मिति (T)"))
                    .disabled(model.isShowingCurrentMonth && model.selectedJDN == nil)
                Button { model.step(months: 1) } label: { Image(systemName: "chevron.right") }
                    .help(model.t("Next month (→)", "अर्को महिना (→)"))
                    .accessibilityLabel(model.t("Next month", "अर्को महिना"))
            }
            .controlSize(.small)
            .fixedSize()
        }
    }

    private func jump(year: Int, month: Int) {
        model.monthStep = (year * 12 + month) - (model.displayYear * 12 + model.displayMonth)
        model.displayYear = year
        model.displayMonth = month
    }

    private var adRange: String {
        guard let start = BSCalendar.startJDN(year: model.displayYear, month: model.displayMonth),
              let len = BSCalendar.daysInMonth(year: model.displayYear, month: model.displayMonth) else { return "" }
        let a = ADDate(jdn: start), b = ADDate(jdn: start + len - 1)
        let am = Formatter.adMonth(a.month, .english, short: true), bm = Formatter.adMonth(b.month, .english, short: true)
        return a.year == b.year ? "\(am) – \(bm) \(b.year)" : "\(am) \(a.year) – \(bm) \(b.year)"
    }
}

struct DayDetail: View {
    @Environment(AppModel.self) private var model
    let jdn: Int

    var body: some View {
        let cal = model.cal
        let bs = BSDate(jdn: jdn)
        let ad = ADDate(jdn: jdn)
        let p = Panchang.shared.day(jdn)
        let events = dedup(FestivalEngine.shared.events(on: jdn))
        let ekEvents = model.settings.showCalendarEvents ? model.calendarService.events(on: ad) : []
        let npt = NepalTime.timeZone

        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(verbatim: bs.map { "\(Formatter.dateLong($0, cal)), \(Formatter.weekday(JDN.weekday(jdn), cal))" } ?? "")
                            .font(.headline)
                        Spacer(minLength: 6)
                        Text(Formatter.relativeDays(jdn - model.todayJDN, model.lang))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(verbatim: "\(Formatter.weekday(JDN.weekday(jdn), .english)), \(Formatter.adLong(ad, .english))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    FactRow(symbol: MoonIcon.name(for: p.tithi), text: Formatter.tithiName(p, cal),
                            detail: model.t("until \(Formatter.time(p.tithiEnds, in: npt, .english)) NPT",
                                            "\(Formatter.time(p.tithiEnds, in: npt, .english)) सम्म"))
                    FactRow(symbol: "sun.horizon",
                            text: "\(Formatter.time(p.sunrise, in: npt, .english)) – \(Formatter.time(p.sunset, in: npt, .english))",
                            detail: model.t("Sunrise to sunset, Kathmandu", "सूर्योदय–सूर्यास्त, काठमाडौं"))
                    if let ns = FestivalEngine.shared.nepalSambat(jdn: jdn) {
                        FactRow(symbol: "calendar", text: model.t("Nepal Sambat \(Formatter.digits(ns, cal))",
                                                                  "नेपाल सम्वत् \(Formatter.digits(ns, cal))"))
                    }
                }

                if !events.isEmpty {
                    VStack(alignment: .leading, spacing: 7) {
                        ForEach(events, id: \.id) { e in EventRow(event: e) }
                    }
                }

                if !ekEvents.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(model.t("From Calendar", "क्यालेन्डरबाट"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ForEach(ekEvents, id: \.eventIdentifier) { ev in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Circle().fill(Color(cgColor: ev.calendar.cgColor)).frame(width: 7, height: 7).frame(width: 16)
                                Text(ev.title ?? "").font(.callout).lineLimit(1)
                                Spacer(minLength: 6)
                                Text(ev.isAllDay ? model.t("All day", "दिनभर") : Formatter.time(ev.startDate, in: .current, .english))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.automatic)
    }

    private func dedup(_ events: [CalendarEvent]) -> [CalendarEvent] {
        var seen = Set<String>()
        return events.filter { seen.insert($0.nameEn).inserted }
    }
}

struct EventRow: View {
    @Environment(AppModel.self) private var model
    let event: CalendarEvent

    var body: some View {
        let cal = model.cal
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Circle()
                .fill(event.isHoliday ? AnyShapeStyle(Palette.holiday) : AnyShapeStyle(.secondary))
                .frame(width: 7, height: 7)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(event.name(cal))
                    .font(.callout.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
                if let note = event.note(model.lang) {
                    Text(note).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 6)
            switch event.category {
            case .publicHoliday:
                Text(model.t("Holiday", "बिदा")).font(.caption).foregroundStyle(Palette.holiday)
            case .regionalHoliday:
                Text(model.t("Regional", "क्षेत्रीय")).font(.caption).foregroundStyle(.secondary)
            default:
                EmptyView()
            }
        }
        .accessibilityElement(children: .combine)
    }
}
