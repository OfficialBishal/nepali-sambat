import SambatCore
import SambatUI
import SwiftUI

struct PanelRoot: View {
    static let size = CGSize(width: 340, height: 670)
    /// Laid out at its natural height, to measure how tall the popover should be (see
    /// `StatusBarController.panelSize`). In the popover itself the panel fills whatever size it's given.
    var measuring = false
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // One layout in every state, pinned to the top: when the popover resizes, only its bottom
        // edge moves and the month stays put.
        VStack(spacing: 0) {
            ZStack {
                switch model.page {
                case .calendar: CalendarPage().transition(.opacity)
                case .converter: ConverterPage().transition(.opacity)
                case .upcoming: UpcomingPage().transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: measuring ? nil : .infinity, alignment: .top)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: model.page)
            Divider()
            BottomBar()
        }
        .frame(width: Self.size.width)
        .frame(maxHeight: measuring ? nil : .infinity)
        .fixedSize(horizontal: false, vertical: measuring)
        .tint(model.palette.accent)
        .background { PanelSurface().ignoresSafeArea() }
    }
}

extension PanelRoot {
    /// The popover's size: the full panel, or on the Calendar page with "Coming up" hidden, the
    /// month's natural height, measured offscreen.
    @MainActor static func size(for model: AppModel) -> CGSize {
        guard model.page == .calendar && model.sectionHidden else { return size }
        let probe = NSHostingView(rootView: PanelRoot(measuring: true).environment(model))
        probe.frame = NSRect(x: 0, y: 0, width: size.width, height: 100)
        let height = ceil(probe.fittingSize.height)
        return CGSize(width: size.width, height: min(max(height, 300), size.height))
    }
}

/// The popover's own surface. The system popover glass adapts to whatever is behind it, so a Light
/// popover over a dark desktop came out grey and low-contrast. This keeps Light light and Dark
/// dark, and it reaches under the arrow (the popover uses full-size content).
struct PanelSurface: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        (scheme == .dark ? Color(white: 0.135) : Color(white: 0.975)).opacity(0.96)
    }
}

/// The soft track every app-drawn control sits on: switchers, menus, icon groups.
struct ControlTrack: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.primary.opacity(0.07))
    }
}

struct BottomBar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        HStack(spacing: 8) {
            PillPicker(selection: $model.page, items: [
                .init(Page.calendar, model.t("Calendar (⌘1)", "पात्रो (⌘1)"), symbol: "calendar"),
                .init(Page.converter, model.t("Convert a date (⌘2)", "मिति रूपान्तरण (⌘2)"), symbol: "arrow.left.arrow.right"),
                .init(Page.upcoming, model.t("Festivals (⌘3)", "चाडपर्व (⌘3)"), symbol: "sparkles"),
            ], segmentWidth: 44)
            .fixedSize()
            .accessibilityLabel(model.t("Page", "पृष्ठ"))

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
                    .background(ControlTrack())
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
/// Segments show a symbol (with the label as tooltip and spoken name) or the label itself.
struct PillPicker<Value: Hashable>: View {
    struct Item {
        let value: Value
        let label: String
        var symbol: String? = nil

        init(_ value: Value, _ label: String, symbol: String? = nil) {
            self.value = value
            self.label = label
            self.symbol = symbol
        }
    }

    static var height: CGFloat { 26 }

    @Binding var selection: Value
    let items: [Item]
    /// Fixed segment width (icon segments); nil shares the available width.
    var segmentWidth: CGFloat? = nil

    @Namespace private var namespace
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items.indices, id: \.self) { i in
                let item = items[i]
                let on = item.value == selection
                Button {
                    withAnimation(reduceMotion ? nil : .snappy(duration: 0.22)) { selection = item.value }
                } label: {
                    Group {
                        if let symbol = item.symbol {
                            Image(systemName: symbol).font(.system(size: 13, weight: on ? .semibold : .regular))
                        } else {
                            Text(item.label).font(.system(size: 12.5, weight: on ? .semibold : .regular)).lineLimit(1)
                        }
                    }
                    .foregroundStyle(on ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                    .frame(maxWidth: segmentWidth == nil ? .infinity : nil)
                    .frame(width: segmentWidth, height: Self.height - 4)
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
                .help(item.symbol == nil ? "" : item.label)
                .accessibilityLabel(item.label)
                .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(2)
        .background(ControlTrack())
        .accessibilityElement(children: .contain)
    }
}

/// A pop-up menu in the app's control style: the value and a chevron on the soft track, instead of
/// the native pop-up button's white bezel and accent badge.
struct MenuField<Value: Hashable>: View {
    let title: String
    @Binding var selection: Value
    let options: [(Value, String)]

    var body: some View {
        Menu {
            Picker(title, selection: $selection) {
                ForEach(options.indices, id: \.self) { i in Text(options[i].1).tag(options[i].0) }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
            HStack(spacing: 6) {
                Text(options.first { $0.0 == selection }?.1 ?? "")
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 9)
            .frame(height: PillPicker<Value>.height)
            .background(ControlTrack())
            .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .accessibilityLabel(title)
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

/// A borderless icon button, like a toolbar item: the symbol alone, a soft highlight on hover and
/// press, a tooltip, and a spoken label. Active shows it filled in the accent (for toggles).
struct IconButton: View {
    let symbol: String
    let label: String
    var active = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13))
                .frame(width: 26, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(IconButtonStyle(active: active))
        .help(label)
        .accessibilityLabel(label)
        .accessibilityAddTraits(active ? .isSelected : [])
    }
}

struct IconButtonStyle: ButtonStyle {
    var active = false

    func makeBody(configuration: Configuration) -> some View {
        IconBody(configuration: configuration, active: active)
    }

    private struct IconBody: View {
        let configuration: ButtonStyleConfiguration
        let active: Bool
        @Environment(\.isEnabled) private var isEnabled
        private var hovered = State(initialValue: false)

        init(configuration: ButtonStyleConfiguration, active: Bool) {
            self.configuration = configuration
            self.active = active
        }

        var body: some View {
            configuration.label
                .foregroundStyle(active ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.primary.opacity(configuration.isPressed ? 0.12 : (hovered.wrappedValue ? 0.07 : 0)))
                )
                .opacity(isEnabled ? 1 : 0.4)
                .onHover { hovered.wrappedValue = $0 }
        }
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
