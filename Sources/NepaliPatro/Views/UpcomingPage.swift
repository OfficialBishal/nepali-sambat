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

    var body: some View {
        let theme = model.theme
        let lang = model.lang
        let days = upcoming()
        VStack(spacing: 8) {
            HStack {
                PageTitle(text: model.t("Upcoming festivals", "आगामी चाडपर्व"))
                Toggle(model.t("Holidays only", "बिदा मात्र"), isOn: $holidaysOnly)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .font(.system(size: 10.5))
                    .fixedSize()
            }
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 6) {
                    ForEach(days) { day in
                        let bs = BSDate(jdn: day.jdn)
                        let ad = ADDate(jdn: day.jdn)
                        Button {
                            model.showMonth(of: day.jdn)
                            model.select(day.jdn)
                            model.page = .calendar
                        } label: {
                            HStack(spacing: 10) {
                                VStack(spacing: 0) {
                                    Text(Formatter.digits(bs?.day ?? 0, lang))
                                        .font(.system(size: 17, weight: .bold, design: .rounded))
                                    Text(Formatter.bsMonth(bs?.month ?? 1, lang))
                                        .font(.system(size: 8.5, weight: .semibold))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                }
                                .foregroundStyle(day.isHoliday ? theme.holiday : theme.primary)
                                .frame(width: 46, height: 42)
                                .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(day.isHoliday ? theme.holiday.opacity(0.12) : theme.card))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(day.names.joined(separator: " · "))
                                        .font(.system(size: 12, weight: .semibold))
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                    Text(verbatim: "\(Formatter.weekday(JDN.weekday(day.jdn), lang, short: true)) · \(Formatter.adLong(ad, .english))")
                                        .font(.system(size: 10))
                                        .foregroundStyle(theme.secondary)
                                }
                                Spacer(minLength: 4)
                                Text(Formatter.relativeDays(day.jdn - model.todayJDN, lang))
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(theme.secondary)
                                    .multilineTextAlignment(.trailing)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
    }

    private func upcoming() -> [Day] {
        let today = model.todayJDN
        let events = FestivalEngine.shared.events(from: today, to: today + 366).filter {
            holidaysOnly ? $0.isPublicHoliday : $0.category != .observance
        }
        let grouped = Dictionary(grouping: events, by: \.jdn)
        return grouped.keys.sorted().map { jdn in
            let list = grouped[jdn]!
            var seen = Set<String>()
            let names = list.map { $0.name(model.lang) }.filter { seen.insert($0).inserted }
            return Day(jdn: jdn, names: names, isHoliday: list.contains { $0.isPublicHoliday })
        }
    }
}
