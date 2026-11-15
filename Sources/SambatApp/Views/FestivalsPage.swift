import SambatCore
import SambatUI
import SwiftUI

/// The year ahead, grouped by Nepali month.
struct FestivalsPage: View {
    @Environment(AppModel.self) private var model
    @AppStorage("upcomingHolidaysOnly") private var holidaysOnly = false

    private struct Day: Identifiable {
        let jdn: Int
        let events: [CalendarEvent]
        var id: Int { jdn }
        var isHoliday: Bool { events.contains { $0.isPublicHoliday } }
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
            LoomHeader {
                HStack(alignment: .firstTextBaseline) {
                    HeaderTitle(text: model.t("Festivals", "चाडपर्व"))
                    Spacer()
                    Toggle(model.t("Public holidays only", "सार्वजनिक बिदा मात्र"), isOn: $holidaysOnly)
                        .toggleStyle(.checkbox)
                        .controlSize(.small)
                }
                HStack(spacing: 12) {
                    legend(.publicHoliday, model.t("Public holiday", "सार्वजनिक बिदा"))
                    legend(.regionalHoliday, model.t("Regional", "क्षेत्रीय"))
                    legend(.festival, model.t("Festival", "चाडपर्व"))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 6)
            }

            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(groups) { group in
                        Section {
                            ForEach(group.days) { day in row(day) }
                        } header: {
                            Text(verbatim: "\(Formatter.bsMonth(group.month, model.cal)) \(Formatter.digits(group.year, model.cal))")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.quiet)
                                .padding(.horizontal, 16)
                                .padding(.top, 10)
                                .padding(.bottom, 4)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding(.bottom, 8)
            }
        }
    }

    private func legend(_ kind: EventMarker.Kind, _ label: String) -> some View {
        HStack(spacing: 5) {
            EventMarker(kind, size: 7, onField: true)
            Text(label)
        }
    }

    private func row(_ day: Day) -> some View {
        Button {
            model.showMonth(of: day.jdn)
            model.select(day.jdn)
            model.page = .calendar
        } label: {
            EventRow(jdn: day.jdn, events: day.events)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
        }
        .buttonStyle(RowButtonStyle())
        .accessibilityHint(model.t("Shows this day in the month", "यो दिन महिनामा देखाउँछ"))
    }

    private func upcoming() -> [MonthGroup] {
        let today = model.todayJDN
        let events = FestivalEngine.shared.events(from: today, to: today + 366).filter {
            holidaysOnly ? $0.isPublicHoliday : $0.category != .observance
        }
        let byDay = Dictionary(grouping: events, by: \.jdn)
        var groups: [MonthGroup] = []
        for jdn in byDay.keys.sorted() {
            guard let bs = BSDate(jdn: jdn) else { continue }
            let day = Day(jdn: jdn, events: byDay[jdn]!)
            if let last = groups.last, last.year == bs.year, last.month == bs.month {
                groups[groups.count - 1] = MonthGroup(year: last.year, month: last.month, days: last.days + [day])
            } else {
                groups.append(MonthGroup(year: bs.year, month: bs.month, days: [day]))
            }
        }
        return groups
    }
}
