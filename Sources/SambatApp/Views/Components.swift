import SambatCore
import SambatUI
import SwiftUI

struct PanelRoot: View {
    static let size = CGSize(width: 340, height: 640)
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                switch model.page {
                case .calendar: CalendarPage().transition(.opacity)
                case .converter: ConverterPage().transition(.opacity)
                case .upcoming: FestivalsPage().transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: model.page)
            Divider()
            BottomBar()
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .background {
            if model.snapshotBackground { Color(nsColor: .windowBackgroundColor) }
        }
    }
}

/// The card that heads every page: a translucent layer on the popover, with continuous corners.
struct LoomHeader<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.5))
            .padding(.horizontal, 10)
            .padding(.top, 10)
    }
}

/// Page title used in the header card of Convert and Festivals.
struct HeaderTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 20, weight: .semibold))
            .accessibilityAddTraits(.isHeader)
    }
}

struct BottomBar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        HStack(spacing: 8) {
            Picker("", selection: $model.page) {
                Text(model.t("Month", "महिना")).tag(Page.calendar)
                Text(model.t("Converter", "रूपान्तरण")).tag(Page.converter)
                Text(model.t("Festivals", "चाडपर्व")).tag(Page.upcoming)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()

            Spacer(minLength: 0)

            Menu {
                Button(model.t("Settings…", "सेटिङ…")) {
                    model.closePopover()
                    model.openSettings(.general)
                }
                .keyboardShortcut(",")
                if model.updateChecker.updateAvailable, let v = model.updateChecker.latestVersion {
                    Button(model.t("Update to \(v)…", "\(v) मा अपडेट गर्नुहोस्…")) {
                        model.closePopover()
                        model.openSettings(.general)
                    }
                }
                Button(model.t("About Sambat", "Sambat बारे")) {
                    model.closePopover()
                    model.openSettings(.about)
                }
                Divider()
                Button(model.t("Quit Sambat", "Sambat बन्द गर्नुहोस्")) { NSApp.terminate(nil) }
                    .keyboardShortcut("q")
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(width: 26, height: 24)
                    .contentShape(Rectangle())
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .overlay(alignment: .topTrailing) {
                if model.updateChecker.updateAvailable {
                    Lozenge().fill(Loom.saffron).frame(width: 7, height: 7).offset(x: 2, y: -1)
                }
            }
            .help(model.t("Settings, updates and quit", "सेटिङ, अपडेट र बन्द"))
            .accessibilityLabel(model.t("Settings and more", "सेटिङ र अन्य"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }
}

/// A plain row that highlights on hover and press, like a native list row.
struct RowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        RowBody(configuration: configuration)
    }

    private struct RowBody: View {
        let configuration: ButtonStyleConfiguration
        private var hovered = State(initialValue: false)

        init(configuration: ButtonStyleConfiguration) {
            self.configuration = configuration
        }

        var body: some View {
            configuration.label
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.primary.opacity(configuration.isPressed ? 0.1 : (hovered.wrappedValue ? 0.05 : 0)))
                        .padding(.horizontal, 8)
                )
                .onHover { hovered.wrappedValue = $0 }
        }
    }
}

/// One line of facts: a symbol, a value, and an optional detail on the right.
struct FactRow: View {
    let symbol: String
    let text: String
    var detail: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 11))
                .foregroundStyle(.quiet)
                .frame(width: 16)
            Text(text)
                .font(.callout)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 6)
            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.quiet)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// A festival in the day panel: marker, name, and a plain-text holiday label so meaning never
/// rests on colour or shape alone.
struct EventLine: View {
    @Environment(AppModel.self) private var model
    let event: CalendarEvent

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Group {
                if let kind = EventMarker.kind(for: event) { EventMarker(kind) } else { Color.clear.frame(width: 7, height: 7) }
            }
            .frame(width: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(event.name(model.cal))
                    .font(.callout.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
                if let label = model.holidayLabel(event) {
                    Text(label)
                        .font(.caption)
                        .foregroundStyle(event.isPublicHoliday ? AnyShapeStyle(Loom.madder) : AnyShapeStyle(.quiet))
                }
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

/// One day of festivals in a list (Coming up, Festivals): marker, names, both dates, and how far off it is.
struct EventRow: View {
    @Environment(AppModel.self) private var model
    let jdn: Int
    let events: [CalendarEvent]

    var body: some View {
        var seen = Set<String>()
        let names = events.map { $0.name(model.cal) }.filter { seen.insert($0).inserted }
        let isHoliday = events.contains { $0.isPublicHoliday }
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Group {
                if let kind = EventMarker.kind(for: events) { EventMarker(kind) } else { Color.clear.frame(width: 7, height: 7) }
            }
            .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(names.joined(separator: ", "))
                    .font(.callout.weight(.medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 8) {
                    Text(model.bsLong(jdn, year: false))
                    Text(model.adCompact(jdn)).foregroundStyle(.quiet)
                }
                .font(.caption)
                .lineLimit(1)
            }
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 2) {
                Text(Formatter.relativeDays(jdn - model.todayJDN, model.lang))
                    .font(.caption)
                    .foregroundStyle(.quiet)
                if isHoliday {
                    Text(model.t("Public holiday", "सार्वजनिक बिदा"))
                        .font(.caption)
                        .foregroundStyle(Loom.madder)
                }
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
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
