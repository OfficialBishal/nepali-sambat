import EventKit
import PatroCore
import PatroUI
import SwiftUI

struct CalendarPage: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let s = model.settings
        let rows = rowCount
        VStack(spacing: 10) {
            TodayHeader()
            MonthHeader()
            MonthGrid(year: model.displayYear, month: model.displayMonth,
                      todayJDN: model.todayJDN,
                      localTodayJDN: s.basis == .nepal ? model.localTodayJDN : model.nepalTodayJDN,
                      selectedJDN: model.selectedJDN,
                      lang: model.lang, theme: model.theme,
                      metrics: .init(cellHeight: rows == 6 ? 39 : 45, showAD: s.showAD, showTithi: s.showTithi),
                      onSelect: { model.select($0) })
            DayDetail(jdn: model.focusJDN)
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var rowCount: Int {
        guard let start = BSCalendar.startJDN(year: model.displayYear, month: model.displayMonth),
              let len = BSCalendar.daysInMonth(year: model.displayYear, month: model.displayMonth) else { return 5 }
        return (JDN.weekday(start) + len + 6) / 7
    }
}

struct TodayHeader: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let theme = model.theme
        let lang = model.lang
        let jdn = model.todayJDN
        let today = model.today
        let p = Panchang.shared.day(jdn)
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(Formatter.dateLong(today, lang))
                        .font(.system(size: 21, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(verbatim: "\(Formatter.weekday(JDN.weekday(jdn), lang)) · \(Formatter.adLong(ADDate(jdn: jdn), .english))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(theme.secondary)
                    HStack(spacing: 4) {
                        Image(systemName: MoonIcon.name(for: p.tithi)).font(.system(size: 10))
                        Text(Formatter.tithiName(p, lang)).lineLimit(1)
                        if let ns = FestivalEngine.shared.nepalSambat(jdn: jdn) {
                            Text(verbatim: "· \(model.t("NS", "ने.सं.")) \(Formatter.digits(ns, lang))").lineLimit(1)
                        }
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(theme.secondary)
                }
                Spacer(minLength: 0)
                NepalClock()
            }
            DayDifferenceBanner()
        }
    }
}

struct NepalClock: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let theme = model.theme
        let lang = model.lang
        let tz = NepalTime.timeZone
        let local = TimeZone.current
        let sameZone = tz.secondsFromGMT(for: model.now) == local.secondsFromGMT(for: model.now)
        VStack(alignment: .trailing, spacing: 1) {
            HStack(spacing: 3) {
                Text("🇳🇵").font(.system(size: 9))
                Text(model.t("NEPAL", "नेपाल")).font(.system(size: 9, weight: .bold)).tracking(0.5)
            }
            .foregroundStyle(theme.secondary)
            Text(Formatter.time(model.now, in: tz, lang, seconds: model.panelVisible))
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .monospacedDigit()
            if !sameZone {
                Text(offsetText(from: local))
                    .font(.system(size: 9))
                    .foregroundStyle(theme.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(theme.card))
    }
}

extension NepalClock {
    func offsetText(from zone: TimeZone) -> String {
        let seconds = NepalTime.offsetSeconds(from: zone, at: model.now)
        let a = abs(seconds)
        let hm = String(format: "%d:%02d", a / 3600, (a % 3600) / 60)
        if seconds >= 0 {
            return model.t("\(hm) ahead of you", "तपाईंभन्दा \(Formatter.digits(hm, .nepali)) अगाडि")
        }
        return model.t("\(hm) behind you", "तपाईंभन्दा \(Formatter.digits(hm, .nepali)) पछाडि")
    }
}

/// Explains when Nepal and this Mac are on different dates. This is the moment the old app got wrong.
struct DayDifferenceBanner: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let theme = model.theme
        let lang = model.lang
        let nepal = model.nepalTodayJDN
        let local = model.localTodayJDN
        if nepal != local {
            let text: String = {
                let localAD = ADDate(jdn: local)
                let localDesc = "\(Formatter.weekday(JDN.weekday(local), lang, short: true)), \(Formatter.adShort(localAD, .english))"
                switch model.settings.basis {
                case .nepal:
                    if nepal > local {
                        return model.t("New day in Nepal. It's still \(localDesc) here.",
                                       "नेपालमा नयाँ दिन सुरु भइसक्यो। यहाँ अझै \(localDesc) हो।")
                    } else {
                        return model.t("Nepal hasn't reached \(localDesc) yet.",
                                       "नेपालमा अझै \(localDesc) आइसकेको छैन।")
                    }
                case .local:
                    let n = BSDate(jdn: nepal).map { Formatter.dateLong($0, lang) } ?? ""
                    return model.t("In Nepal it's \(n).", "नेपालमा आज \(n) हो।")
                }
            }()
            HStack(spacing: 6) {
                Image(systemName: "globe.asia.australia.fill").font(.system(size: 10))
                Text(text).font(.system(size: 10.5, weight: .medium)).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .foregroundStyle(theme.accent)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(theme.accent.opacity(0.1)))
        }
    }
}

struct MonthHeader: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let theme = model.theme
        let lang = model.lang
        let isCurrent = model.today.year == model.displayYear && model.today.month == model.displayMonth
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 4) {
                    Menu {
                        ForEach(1...12, id: \.self) { m in
                            Button(Formatter.bsMonth(m, lang)) { model.displayMonth = m }
                        }
                    } label: {
                        Text(Formatter.bsMonth(model.displayMonth, lang))
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    Menu {
                        ForEach((BSCalendar.firstYear...BSCalendar.lastYear).reversed(), id: \.self) { y in
                            Button(Formatter.digits(y, lang)) { model.displayYear = y }
                        }
                    } label: {
                        Text(Formatter.digits(model.displayYear, lang))
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                }
                .font(.system(size: 15, weight: .bold, design: .rounded))
                Text(adRange)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(theme.secondary)
                    .lineLimit(1)
                    .fixedSize()
            }
            Spacer(minLength: 0)
            if !isCurrent || model.selectedJDN != nil {
                PillButton(title: model.t("Today", "आज"), systemImage: "arrow.uturn.backward") { model.goToToday() }
            }
            IconButton(systemName: "chevron.left", help: model.t("Previous month (←)", "अघिल्लो महिना (←)")) { model.step(months: -1) }
            IconButton(systemName: "chevron.right", help: model.t("Next month (→)", "अर्को महिना (→)")) { model.step(months: 1) }
        }
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
        let theme = model.theme
        let lang = model.lang
        let bs = BSDate(jdn: jdn)
        let ad = ADDate(jdn: jdn)
        let p = Panchang.shared.day(jdn)
        let events = dedup(FestivalEngine.shared.events(on: jdn))
        let ekEvents = model.settings.showCalendarEvents ? model.calendarService.events(on: ad) : []
        let npt = NepalTime.timeZone

        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline) {
                    Text(bs.map { "\(Formatter.dateLong($0, lang)), \(Formatter.weekday(JDN.weekday(jdn), lang))" } ?? "")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer(minLength: 4)
                    Text(Formatter.relativeDays(jdn - model.todayJDN, lang))
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(theme.secondary)
                }
                Text(verbatim: "\(Formatter.weekday(JDN.weekday(jdn), .english)), \(Formatter.adLong(ad, .english))")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.secondary)
                HStack(spacing: 5) {
                    Image(systemName: MoonIcon.name(for: p.tithi)).frame(width: 14)
                    Text(Formatter.tithiName(p, lang))
                    Text("· " + model.t("until \(Formatter.time(p.tithiEnds, in: npt, .english)) NPT",
                                       "\(Formatter.time(p.tithiEnds, in: npt, lang)) सम्म"))
                        .foregroundStyle(theme.secondary)
                }
                .font(.system(size: 11))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                HStack(spacing: 5) {
                    Image(systemName: "sunrise").frame(width: 14)
                    Text(verbatim: "\(Formatter.time(p.sunrise, in: npt, lang)) · \(Formatter.time(p.sunset, in: npt, lang))")
                    Text(model.t("Kathmandu", "काठमाडौं")).foregroundStyle(theme.secondary)
                }
                .font(.system(size: 11))

                if !events.isEmpty {
                    Divider().opacity(0.4)
                    ForEach(events, id: \.id) { e in
                        HStack(alignment: .top, spacing: 8) {
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(e.isHoliday ? theme.holiday : theme.festival)
                                .frame(width: 3, height: 30)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(e.name(lang)).font(.system(size: 12.5, weight: .semibold))
                                    .fixedSize(horizontal: false, vertical: true)
                                HStack(spacing: 5) {
                                    CategoryTag(category: e.category)
                                    if let note = e.note(lang) {
                                        Text(note).font(.system(size: 9.5)).foregroundStyle(theme.secondary).lineLimit(1)
                                    }
                                }
                            }
                        }
                    }
                }
                if !ekEvents.isEmpty {
                    Divider().opacity(0.4)
                    SectionLabel(text: model.t("Your events", "तपाईंका कार्यक्रम"))
                    ForEach(ekEvents, id: \.eventIdentifier) { ev in
                        HStack(spacing: 7) {
                            Circle().fill(Color(cgColor: ev.calendar.cgColor)).frame(width: 7, height: 7)
                            Text(ev.title ?? "").font(.system(size: 11.5, weight: .medium)).lineLimit(1)
                            Spacer(minLength: 4)
                            Text(ev.isAllDay ? model.t("All day", "दिनभर") : Formatter.time(ev.startDate, in: .current, .english))
                                .font(.system(size: 10)).foregroundStyle(theme.secondary)
                        }
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(theme.card))
    }

    private func dedup(_ events: [CalendarEvent]) -> [CalendarEvent] {
        var seen = Set<String>()
        return events.filter { seen.insert($0.nameEn).inserted }
    }
}
