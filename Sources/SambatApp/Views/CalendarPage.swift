import EventKit
import SambatCore
import SambatUI
import SwiftUI

struct CalendarPage: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let s = model.settings
        let rows = MonthGrid.rows(year: model.displayYear, month: model.displayMonth)
        VStack(alignment: .leading, spacing: 0) {
            TodayHeader()
            MonthBar()
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 6)
            MonthGrid(year: model.displayYear, month: model.displayMonth,
                      todayJDN: model.todayJDN,
                      otherTodayJDN: s.basis == .nepal ? model.localTodayJDN : model.nepalTodayJDN,
                      selectedJDN: model.selectedJDN,
                      lang: model.cal, uiLanguage: model.lang,
                      metrics: .init(cellHeight: rows == 6 ? 44 : 48, rowSpacing: rows == 6 ? 1 : 3,
                                     numeralSize: 15, marker: rows == 6 ? 25 : 28,
                                     showAD: s.showAD, showTithi: s.showTithi),
                      onSelect: { model.select($0) })
                .padding(.horizontal, 16)
                .id(model.displayYear * 12 + model.displayMonth)
                .transition(monthTransition)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: model.displayYear * 12 + model.displayMonth)
            Divider().padding(.horizontal, 16).padding(.top, 4)
            Group {
                if let selected = model.selectedJDN {
                    DayPanel(jdn: selected)
                } else {
                    ComingUp()
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
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

/// Today in Nepal, on the loom field: the date, the Nepal clock, and the woven tithi band.
struct TodayHeader: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let cal = model.cal
        let jdn = model.todayJDN
        let today = model.today
        let p = Panchang.shared.day(jdn)
        let showClock = NepalTime.offsetSeconds(from: .current, at: model.now) != 0
        let events = dedup(FestivalEngine.shared.events(on: jdn).filter { $0.category != .observance })

        LoomHeader {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(verbatim: "\(Formatter.bsMonth(today.month, cal)) \(Formatter.digits(today.day, cal))")
                        .font(.system(size: 24, weight: .semibold))
                    Text(Formatter.digits(today.year, cal))
                        .font(.system(size: 24, weight: .light))
                        .foregroundStyle(.secondary)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                if showClock {
                    Text(model.clock(model.now))
                        .font(.system(size: 15, weight: .medium))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(Formatter.weekday(JDN.weekday(jdn), cal))
                Text(model.adMedium(jdn)).foregroundStyle(.secondary)
                Spacer(minLength: 6)
                if showClock { Text(model.t("Nepal time", "नेपाली समय")).foregroundStyle(.secondary) }
            }
            .font(.subheadline)
            .padding(.top, 2)

            TithiBand(tithi: p.tithi, lang: model.lang, animated: true)
                .padding(.top, 14)
            HStack(alignment: .firstTextBaseline) {
                Text(Formatter.tithiShort(p, cal))
                    .font(.subheadline.weight(.medium))
                Spacer(minLength: 6)
                Text(model.tithiEnd(p))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 6)

            ForEach(events, id: \.id) { e in
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    if let kind = EventMarker.kind(for: e) { EventMarker(kind, onField: true) }
                    Text(e.name(cal)).font(.subheadline.weight(.semibold))
                    if e.isPublicHoliday {
                        Text(model.t("Public holiday", "सार्वजनिक बिदा")).font(.caption).foregroundStyle(Loom.madder)
                    }
                }
                .padding(.top, 6)
            }

            DayDifferenceNote().padding(.top, 10)
        }
    }

    private func dedup(_ events: [CalendarEvent]) -> [CalendarEvent] {
        var seen = Set<String>()
        return events.filter { seen.insert($0.nameEn).inserted }
    }
}

/// Shown when Nepal and this Mac are on different dates: the moment other apps get wrong.
struct DayDifferenceNote: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let nepal = model.nepalTodayJDN
        let local = model.localTodayJDN
        if nepal != local {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: "clock")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Loom.saffron)
                Text(message(nepal: nepal, local: local))
                    .font(.subheadline)
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
            return model.t("It’s \(nepalDay) in Nepal and still \(localDay), \(localDate) here.",
                           "नेपालमा \(nepalDay) भइसक्यो, यहाँ अझै \(localDay), \(localDate)।")
        case .nepal:
            return model.t("It’s still \(nepalDay) in Nepal and already \(localDay), \(localDate) here.",
                           "नेपालमा अझै \(nepalDay), यहाँ \(localDay), \(localDate) भइसक्यो।")
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
                    .foregroundStyle(.quiet)
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
        model.clearSelectionOutsideDisplayedMonth()
    }

    private var adRange: String {
        guard let start = BSCalendar.startJDN(year: model.displayYear, month: model.displayMonth),
              let len = BSCalendar.daysInMonth(year: model.displayYear, month: model.displayMonth) else { return "" }
        let a = ADDate(jdn: start), b = ADDate(jdn: start + len - 1)
        let am = Formatter.adMonth(a.month, .english, short: true), bm = Formatter.adMonth(b.month, .english, short: true)
        return a.year == b.year ? "\(am) – \(bm) \(b.year)" : "\(am) \(a.year) – \(bm) \(b.year)"
    }
}

/// The selected day: its date, tithi, sun times, festivals and the user's own events.
struct DayPanel: View {
    @Environment(AppModel.self) private var model
    let jdn: Int

    var body: some View {
        let cal = model.cal
        let p = Panchang.shared.day(jdn)
        let events = dedup(FestivalEngine.shared.events(on: jdn).filter { $0.category != .observance })
        let ekEvents = model.settings.showCalendarEvents ? model.calendarService.events(on: ADDate(jdn: jdn)) : []

        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(model.bsLong(jdn, year: false)).font(.headline)
                        Spacer(minLength: 6)
                        Text(model.relative(jdn))
                            .font(.caption)
                            .foregroundStyle(.quiet)
                    }
                    Text(model.adMedium(jdn))
                        .font(.subheadline)
                        .foregroundStyle(.quiet)
                }
                VStack(alignment: .leading, spacing: 6) {
                    FactRow(symbol: MoonIcon.name(for: p.tithi), text: Formatter.tithiShort(p, cal), detail: model.tithiEnd(p))
                    FactRow(symbol: "sun.horizon", text: "\(model.clock(p.sunrise)) – \(model.clock(p.sunset))",
                            detail: model.t("Sunrise, sunset in Kathmandu", "काठमाडौंमा सूर्योदय, सूर्यास्त"))
                }
                if !events.isEmpty {
                    VStack(alignment: .leading, spacing: 7) {
                        ForEach(events, id: \.id) { e in EventLine(event: e) }
                    }
                }
                if !ekEvents.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(model.t("From your calendars", "तपाईंको क्यालेन्डरबाट"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.quiet)
                        ForEach(ekEvents, id: \.eventIdentifier) { ev in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Lozenge().fill(Color(cgColor: ev.calendar.cgColor)).frame(width: 7, height: 7).frame(width: 16)
                                Text(ev.title ?? "").font(.callout).lineLimit(1)
                                Spacer(minLength: 6)
                                Text(ev.isAllDay ? model.t("All day", "दिनभर") : model.clock(ev.startDate, in: .current))
                                    .font(.caption)
                                    .foregroundStyle(.quiet)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func dedup(_ events: [CalendarEvent]) -> [CalendarEvent] {
        var seen = Set<String>()
        return events.filter { seen.insert($0.nameEn).inserted }
    }
}

/// With nothing selected: the next few festivals, so the space under the month looks forward.
/// Shows as many whole rows as fit (three, two or one), never a row cut in half.
struct ComingUp: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let today = model.todayJDN
        let events = FestivalEngine.shared.events(from: today + 1, to: today + 120).filter { $0.category != .observance }
        let byDay = Dictionary(grouping: events, by: \.jdn)
        let days = Array(byDay.keys.sorted().prefix(3))

        ViewThatFits(in: .vertical) {
            list(Array(days.prefix(3)), byDay)
            list(Array(days.prefix(2)), byDay)
            list(Array(days.prefix(1)), byDay)
            Color.clear.frame(height: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func list(_ days: [Int], _ byDay: [Int: [CalendarEvent]]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(model.t("Coming up", "आउँदै गरेका"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.quiet)
                .padding(.horizontal, 16)
                .padding(.bottom, 2)
            ForEach(days, id: \.self) { jdn in
                Button {
                    model.showMonth(of: jdn)
                    model.select(jdn)
                } label: {
                    EventRow(jdn: jdn, events: byDay[jdn] ?? [])
                        .padding(.horizontal, 16)
                        .padding(.vertical, 4)
                }
                .buttonStyle(RowButtonStyle())
            }
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
