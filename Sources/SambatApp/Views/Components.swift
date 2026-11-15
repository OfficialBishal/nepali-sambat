import SambatCore
import SambatUI
import SwiftUI

struct PanelRoot: View {
    static let size = CGSize(width: 340, height: 596)
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        @Bindable var model = model
        VStack(spacing: 0) {
            ZStack {
                switch model.page {
                case .calendar: CalendarPage().transition(.opacity)
                case .converter: ConverterPage().transition(.opacity)
                case .upcoming: UpcomingPage().transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: model.page)
            Divider()
            BottomBar()
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .tint(model.palette.accent)
        .background {
            if model.snapshotBackground { Color(nsColor: .windowBackgroundColor) }
        }
    }
}

struct BottomBar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        HStack(spacing: 8) {
            PillPicker(selection: $model.page, items: [
                (Page.calendar, model.t("Calendar", "पात्रो")),
                (Page.converter, model.t("Convert", "रूपान्तरण")),
                (Page.upcoming, model.t("Festivals", "चाडपर्व")),
            ])
            .accessibilityLabel(model.t("Page", "पृष्ठ"))

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
                Button(model.t("About Nepali Sambat", "Nepali Sambat बारे")) {
                    model.closePopover()
                    model.openSettings(.about)
                }
                Divider()
                Button(model.t("Quit Nepali Sambat", "Nepali Sambat बन्द गर्नुहोस्")) { NSApp.terminate(nil) }
                    .keyboardShortcut("q")
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(width: PillPicker<Page>.height + 4, height: PillPicker<Page>.height)
                    .background(PillPicker<Page>.track)
                    .contentShape(Rectangle())
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .overlay(alignment: .topTrailing) {
                if model.updateChecker.updateAvailable {
                    Circle().fill(model.palette.accent).frame(width: 7, height: 7).offset(x: 2, y: -2)
                }
            }
            .help(model.t("Settings, updates and quit", "सेटिङ, अपडेट र बन्द"))
            .accessibilityLabel(model.t("Settings and more", "सेटिङ र अन्य"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }
}

/// A segmented control drawn the way current macOS draws one in a form: a soft track with the
/// chosen segment raised. A native segmented control in a popover switches to a heavy accent
/// fill, and greys out whenever the popover isn't the key window; this looks the same either way.
struct PillPicker<Value: Hashable>: View {
    static var height: CGFloat { 26 }
    static var track: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.primary.opacity(0.07))
    }

    @Binding var selection: Value
    let items: [(Value, String)]

    @Namespace private var namespace
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items.indices, id: \.self) { i in
                let (value, label) = items[i]
                let on = value == selection
                Button {
                    withAnimation(reduceMotion ? nil : .snappy(duration: 0.22)) { selection = value }
                } label: {
                    Text(label)
                        .font(.system(size: 12.5, weight: on ? .semibold : .regular))
                        .foregroundStyle(on ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .frame(height: Self.height - 4)
                        .background {
                            if on {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(scheme == .dark ? Color.white.opacity(0.17) : Color.white)
                                    .shadow(color: .black.opacity(scheme == .dark ? 0.35 : 0.14), radius: 1.5, y: 0.5)
                                    .matchedGeometryEffect(id: "selection", in: namespace)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(2)
        .background(Self.track)
        .accessibilityElement(children: .contain)
    }
}

/// A festival in the day detail: dot, name, and a plain-text label so holiday status never
/// rests on colour alone.
struct EventLine: View {
    @Environment(AppModel.self) private var model
    let event: CalendarEvent

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Group {
                if let kind = EventDot.kind(for: [event]) { EventDot(kind) } else { Color.clear.frame(width: 7, height: 7) }
            }
            .frame(width: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(event.name(model.cal))
                    .font(.callout.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
                if let label = model.holidayLabel(event) {
                    Text(label)
                        .font(.caption)
                        .foregroundStyle(event.isPublicHoliday ? AnyShapeStyle(Palette.holiday) : AnyShapeStyle(.quiet))
                }
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

/// One day of festivals in a list (Coming up, Festivals), patro style: the day number on the left,
/// red on a public holiday, with the month above it where the list has no month headings.
struct FestivalRow: View {
    @Environment(AppModel.self) private var model
    let jdn: Int
    let events: [CalendarEvent]
    var showsMonth = false

    var body: some View {
        let cal = model.cal
        let bs = BSDate(jdn: jdn)
        var seen = Set<String>()
        let names = events.map { $0.name(cal) }.filter { seen.insert($0).inserted }
        let isHoliday = events.contains { $0.isPublicHoliday }
        HStack(alignment: .center, spacing: 12) {
            VStack(spacing: 0) {
                if showsMonth, let bs {
                    Text(verbatim: Formatter.bsMonth(bs.month, cal))
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(.quiet)
                        .lineLimit(1)
                        .fixedSize()
                }
                Text(verbatim: Formatter.digits(bs?.day ?? 0, cal))
                    .font(.system(size: 17, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(isHoliday ? AnyShapeStyle(Palette.holiday) : AnyShapeStyle(.primary))
            }
            .frame(width: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: names.joined(separator: ", "))
                    .font(.callout.weight(.medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(verbatim: "\(Formatter.weekday(JDN.weekday(jdn), cal)), \(model.adCompact(jdn))")
                    .font(.caption)
                    .foregroundStyle(.quiet)
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 2) {
                Text(model.relative(jdn))
                    .font(.caption)
                    .foregroundStyle(.quiet)
                if isHoliday {
                    Text(model.t("Public holiday", "सार्वजनिक बिदा"))
                        .font(.caption)
                        .foregroundStyle(Palette.holiday)
                }
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
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

/// One line of facts: a symbol, a value and an optional detail on the right.
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
