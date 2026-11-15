import PatroCore
import PatroUI
import SwiftUI

struct PanelRoot: View {
    static let size = CGSize(width: 344, height: 616)
    @Environment(AppModel.self) private var model

    var body: some View {
        let theme = model.theme
        VStack(spacing: 0) {
            Group {
                switch model.page {
                case .calendar: CalendarPage()
                case .converter: ConverterPage()
                case .upcoming: UpcomingPage()
                case .settings: SettingsPage()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            Rectangle().fill(theme.secondary.opacity(0.15)).frame(height: 0.5)
            FooterBar()
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .background(theme.background)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(theme.isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.10), lineWidth: 0.5)
        )
        .foregroundStyle(theme.primary)
        .tint(theme.accent)
        .environment(\.colorScheme, theme.colorScheme)
    }
}

struct FooterBar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let theme = model.theme
        HStack(spacing: 2) {
            tab(.calendar, "calendar", model.t("Calendar", "पात्रो"))
            tab(.converter, "arrow.left.arrow.right", model.t("Convert", "रूपान्तरण"))
            tab(.upcoming, "sparkles", model.t("Festivals", "चाडपर्व"))
            tab(.settings, "gearshape", model.t("Settings", "सेटिङ"), badge: model.updateChecker.updateAvailable)
            Spacer(minLength: 0)
            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.secondary)
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(model.t("Quit Nepali Patro", "बन्द गर्नुहोस्"))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    private func tab(_ page: Page, _ icon: String, _ title: String, badge: Bool = false) -> some View {
        let theme = model.theme
        let selected = model.page == page
        return Button {
            model.page = page
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 11, weight: .semibold))
                if selected { Text(title).font(.system(size: 11, weight: .semibold)).lineLimit(1) }
            }
            .padding(.horizontal, selected ? 9 : 7)
            .frame(height: 26)
            .foregroundStyle(selected ? theme.onAccent : theme.secondary)
            .background(Capsule().fill(selected ? theme.accent : Color.clear))
            .overlay(alignment: .topTrailing) {
                if badge { Circle().fill(theme.holiday).frame(width: 6, height: 6).offset(x: -2, y: 3) }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(title)
    }
}

struct Card<Content: View>: View {
    @Environment(AppModel.self) private var model
    var padding: CGFloat = 10
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) { content }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(model.theme.card))
    }
}

struct PageTitle: View {
    @Environment(AppModel.self) private var model
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 17, weight: .bold, design: .rounded))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SectionLabel: View {
    @Environment(AppModel.self) private var model
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 9.5, weight: .semibold))
            .tracking(0.6)
            .foregroundStyle(model.theme.secondary)
    }
}

struct CategoryTag: View {
    @Environment(AppModel.self) private var model
    let category: EventCategory

    var body: some View {
        let theme = model.theme
        let (en, ne, color): (String, String, Color) = {
            switch category {
            case .publicHoliday: return ("Holiday", "सार्वजनिक बिदा", theme.holiday)
            case .regionalHoliday: return ("Regional holiday", "क्षेत्रीय बिदा", theme.holiday.opacity(0.75))
            case .festival: return ("Festival", "चाडपर्व", theme.festival)
            case .observance: return ("Observance", "दिवस", theme.secondary)
            }
        }()
        Text(model.t(en, ne))
            .font(.system(size: 9, weight: .semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(color)
            .background(Capsule().fill(color.opacity(0.13)))
    }
}

struct IconButton: View {
    @Environment(AppModel.self) private var model
    let systemName: String
    var help: String = ""
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .bold))
                .frame(width: 26, height: 24)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(model.theme.card))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

struct PillButton: View {
    @Environment(AppModel.self) private var model
    let title: String
    var systemImage: String? = nil
    var prominent = false
    let action: () -> Void

    var body: some View {
        let theme = model.theme
        Button(action: action) {
            HStack(spacing: 4) {
                if let systemImage { Image(systemName: systemImage).font(.system(size: 10, weight: .semibold)) }
                Text(title).font(.system(size: 11, weight: .semibold)).lineLimit(1)
            }
            .padding(.horizontal, 10)
            .frame(height: 24)
            .foregroundStyle(prominent ? theme.onAccent : theme.primary)
            .background(Capsule().fill(prominent ? theme.accent : theme.card))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

enum MoonIcon {
    static func name(for tithi: Int) -> String {
        switch tithi {
        case 30: return "moonphase.new.moon"
        case 1...3: return "moonphase.waxing.crescent"
        case 4...7: return "moonphase.first.quarter"
        case 8...14: return "moonphase.waxing.gibbous"
        case 15: return "moonphase.full.moon"
        case 16...22: return "moonphase.waning.gibbous"
        case 23...26: return "moonphase.last.quarter"
        default: return "moonphase.waning.crescent"
        }
    }
}
