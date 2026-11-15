import PatroCore
import PatroUI
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
            Picker("", selection: $model.page) {
                Text(model.t("Calendar", "पात्रो")).tag(Page.calendar)
                Text(model.t("Convert", "रूपान्तरण")).tag(Page.converter)
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
                Button(model.t("About Nepali Patro", "नेपाली पात्रोबारे")) {
                    model.closePopover()
                    model.openSettings(.about)
                }
                Divider()
                Button(model.t("Quit Nepali Patro", "नेपाली पात्रो बन्द गर्नुहोस्")) { NSApp.terminate(nil) }
                    .keyboardShortcut("q")
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 22)
                    .contentShape(Rectangle())
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .overlay(alignment: .topTrailing) {
                if model.updateChecker.updateAvailable {
                    Circle().fill(model.palette.accent).frame(width: 6, height: 6).offset(x: 3, y: -2)
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
                        .padding(.horizontal, 6)
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
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text(text)
                .font(.callout)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 6)
            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
