import AppKit
import SambatCore
import SwiftUI

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }

    /// A color that resolves differently in light and dark appearances.
    static func adaptive(light: UInt32, dark: UInt32) -> NSColor {
        NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(hex: dark) : NSColor(hex: light)
        }
    }
}

/// The app's whole color vocabulary: neutral system greys, plus three colours with one job each.
/// The accent marks today and the selection, brick red marks holidays (as a printed patro does),
/// and a warm tan marks festivals. Everything else uses system semantic colors.
public struct Palette: Sendable {
    /// Today and the current selection.
    public let accent: Color
    /// Text drawn on top of `accent`.
    public let onAccent: Color

    /// Holidays and Saturdays, in the red a printed patro uses: a warm brick red rather than a
    /// saturated crimson, so a month full of holidays isn't loud.
    public static let holiday = Color(nsColor: .adaptive(light: 0xB8342E, dark: 0xEF756B))
    /// Festival markers that aren't holidays.
    public static let festival = Color(nsColor: .adaptive(light: 0x9A6F45, dark: 0xCDA27A))

    public init(_ choice: AccentChoice) {
        switch choice {
        case .blue:
            accent = Color(nsColor: .adaptive(light: 0x2864DC, dark: 0x4D8DF7))
            onAccent = .white
        case .teal:
            accent = Color(nsColor: .adaptive(light: 0x0B7782, dark: 0x3DBFC8))
            onAccent = Color(nsColor: .adaptive(light: 0xFFFFFF, dark: 0x052A2E))
        case .green:
            accent = Color(nsColor: .adaptive(light: 0x2E7A45, dark: 0x5BC47D))
            onAccent = Color(nsColor: .adaptive(light: 0xFFFFFF, dark: 0x0B2A14))
        case .purple:
            accent = Color(nsColor: .adaptive(light: 0x6747C7, dark: 0xA68DFF))
            onAccent = Color(nsColor: .adaptive(light: 0xFFFFFF, dark: 0x1C0F3D))
        case .graphite:
            accent = Color(nsColor: .adaptive(light: 0x545862, dark: 0xB2B6BE))
            onAccent = Color(nsColor: .adaptive(light: 0xFFFFFF, dark: 0x1C1C1E))
        case .system:
            accent = Color(nsColor: .controlAccentColor)
            onAccent = .white
        }
    }

    public static func name(_ choice: AccentChoice, _ lang: Language) -> String {
        switch (choice, lang) {
        case (.blue, .english): return "Blue"
        case (.blue, .nepali): return "नीलो"
        case (.teal, .english): return "Teal"
        case (.teal, .nepali): return "टिल"
        case (.green, .english): return "Green"
        case (.green, .nepali): return "हरियो"
        case (.purple, .english): return "Jacaranda"
        case (.purple, .nepali): return "जकरान्डा"
        case (.graphite, .english): return "Graphite"
        case (.graphite, .nepali): return "ग्राफाइट"
        case (.system, .english): return "macOS accent color"
        case (.system, .nepali): return "म्याकको मुख्य रङ"
        }
    }
}

public extension AppearanceMode {
    var nsAppearance: NSAppearance? {
        switch self {
        case .auto: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .auto: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

public extension ShapeStyle where Self == Color {
    /// Small supporting text. The system secondary grey falls under 4.5:1 at caption sizes;
    /// this stays readable in both appearances.
    static var quiet: Color { Color.primary.opacity(0.68) }
}

/// The one festival marker, used in the grid, lists and widgets. Fill carries the meaning as well
/// as colour: a red dot is a public holiday, a red ring a regional holiday, a tan dot a festival.
public struct EventDot: View {
    public enum Kind: Sendable { case publicHoliday, regionalHoliday, festival }

    let kind: Kind
    let size: CGFloat

    public init(_ kind: Kind, size: CGFloat = 7) {
        self.kind = kind
        self.size = size
    }

    public static func kind(for events: [CalendarEvent]) -> Kind? {
        if events.contains(where: { $0.category == .publicHoliday }) { return .publicHoliday }
        if events.contains(where: { $0.category == .regionalHoliday }) { return .regionalHoliday }
        if events.contains(where: { $0.category == .festival }) { return .festival }
        return nil
    }

    public var body: some View {
        Group {
            switch kind {
            case .publicHoliday: Circle().fill(Palette.holiday)
            case .regionalHoliday: Circle().strokeBorder(Palette.holiday, lineWidth: max(1, size * 0.22))
            case .festival: Circle().fill(Palette.festival)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// The SF Symbol for the moon phase of a tithi.
public enum MoonIcon {
    public static func name(for tithi: Int) -> String {
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
