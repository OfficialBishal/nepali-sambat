import SambatCore
import SambatUI
import SwiftUI

struct UpcomingPage: View {
    @Environment(AppModel.self) private var model
    @AppStorage("upcomingHolidaysOnly") private var holidaysOnly = false

    private struct Day: Identifiable {
        let jdn: Int
        let events: [CalendarEvent]
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
                Text(model.t("Festivals", "चाडपर्व"))
                    .font(.title3.weight(.semibold))
                Spacer()
                Toggle(model.t("Public holidays only", "सार्वजनिक बिदा मात्र"), isOn: $holidaysOnly)
                    .toggleStyle(.checkbox)
                    .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 2)

            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(groups) { group in
                        Section {
                            ForEach(group.days) { day in row(day) }
                        } header: {
                            Text(verbatim: "\(Formatter.bsMonth(group.month, model.cal)) \(Formatter.digits(group.year, model.cal))")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.quiet)
                                .padding(.horizontal, 16)
                                .padding(.top, 10)
                                .padding(.bottom, 2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding(.bottom, 8)
            }
        }
    }

    private func row(_ day: Day) -> some View {
        Button { model.reveal(day.jdn) } label: {
            FestivalRow(jdn: day.jdn, events: day.events)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
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
        let days: [Day] = byDay.keys.sorted().map { Day(jdn: $0, events: byDay[$0]!) }
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
