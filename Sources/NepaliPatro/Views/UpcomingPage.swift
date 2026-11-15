import PatroCore
import PatroUI
import SwiftUI

struct UpcomingPage: View {
    @Environment(AppModel.self) private var model
    @AppStorage("upcomingHolidaysOnly") private var holidaysOnly = false

    private struct Day: Identifiable {
        let jdn: Int
        let names: [String]
        let isHoliday: Bool
        var id: Int { jdn }
    }

    private struct MonthGroup: Identifiable {
        let year: Int
        let month: Int
        let days: [Day]
        var id: Int { year * 12 + month }
    }

    var body: some View {
        let groups = upcoming()
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(model.t("Upcoming", "आगामी चाडपर्व"))
                    .font(.title3.weight(.semibold))
                Spacer()
                Toggle(model.t("Holidays only", "बिदा मात्र"), isOn: $holidaysOnly)
                    .toggleStyle(.checkbox)
                    .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 6)

            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    ForEach(groups) { group in
                        Section {
                            ForEach(group.days) { day in row(day) }
                        } header: {
                            Text(verbatim: "\(Formatter.bsMonth(group.month, model.cal)) \(Formatter.digits(group.year, model.cal))")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 5)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.bar)
                        }
                    }
                }
                .padding(.bottom, 8)
            }
        }
    }

    private func row(_ day: Day) -> some View {
        let cal = model.cal
        let bs = BSDate(jdn: day.jdn)
        let ad = ADDate(jdn: day.jdn)
        return Button {
            model.showMonth(of: day.jdn)
            model.select(day.jdn)
            model.page = .calendar
        } label: {
            HStack(alignment: .center, spacing: 12) {
                Text(Formatter.digits(bs?.day ?? 0, cal))
                    .font(.system(size: 17, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(day.isHoliday ? AnyShapeStyle(Palette.holiday) : AnyShapeStyle(.primary))
                    .frame(width: 28, alignment: .trailing)
                VStack(alignment: .leading, spacing: 2) {
                    Text(day.names.joined(separator: ", "))
                        .font(.callout.weight(.medium))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(verbatim: "\(Formatter.weekday(JDN.weekday(day.jdn), cal)), \(Formatter.adShort(ad, .english))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 6)
                Text(Formatter.relativeDays(day.jdn - model.todayJDN, model.lang))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(RowButtonStyle())
        .accessibilityHint(model.t("Shows this day in the calendar", "यो दिन पात्रोमा देखाउँछ"))
    }

    private func upcoming() -> [MonthGroup] {
        let today = model.todayJDN
        let events = FestivalEngine.shared.events(from: today, to: today + 366).filter {
            holidaysOnly ? $0.isPublicHoliday : $0.category != .observance
        }
        let byDay = Dictionary(grouping: events, by: \.jdn)
        let days: [Day] = byDay.keys.sorted().map { jdn in
            let list = byDay[jdn]!
            var seen = Set<String>()
            let names = list.map { $0.name(model.cal) }.filter { seen.insert($0).inserted }
            return Day(jdn: jdn, names: names, isHoliday: list.contains { $0.isPublicHoliday })
        }
        var groups: [MonthGroup] = []
        for day in days {
            guard let bs = BSDate(jdn: day.jdn) else { continue }
            if let last = groups.last, last.year == bs.year, last.month == bs.month {
                groups[groups.count - 1] = MonthGroup(year: last.year, month: last.month, days: last.days + [day])
            } else {
                groups.append(MonthGroup(year: bs.year, month: bs.month, days: [day]))
            }
        }
        return groups
    }
}
