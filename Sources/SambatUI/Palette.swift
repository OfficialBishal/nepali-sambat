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

/// The app's whole color vocabulary. Everything else uses system semantic colors.
public struct Palette: Sendable {
    /// Today and the current selection.
    public let accent: Color
    /// Text drawn on top of `accent`.
    public let onAccent: Color

    /// Holidays and Saturdays, as printed in red in a Nepali patro (crimson from the flag).
    public static let holiday = Color(nsColor: .adaptive(light: 0xC0122C, dark: 0xFF6B70))

    public init(_ choice: AccentChoice) {
        switch choice {
        case .system:
            accent = Color(nsColor: .controlAccentColor)
            onAccent = .white
        case .blue:
            accent = Color(nsColor: .adaptive(light: 0x1D4FB8, dark: 0x5E8EF7))
            onAccent = .white
        case .teal:
            accent = Color(nsColor: .adaptive(light: 0x00707A, dark: 0x3CC2CC))
            onAccent = Color(nsColor: .adaptive(light: 0xFFFFFF, dark: 0x06272A))
        case .green:
            accent = Color(nsColor: .adaptive(light: 0x2F7A34, dark: 0x5DC46B))
            onAccent = Color(nsColor: .adaptive(light: 0xFFFFFF, dark: 0x0B2A10))
        case .marigold:
            accent = Color(nsColor: .adaptive(light: 0xA85F00, dark: 0xF5A623))
            onAccent = Color(nsColor: .adaptive(light: 0xFFFFFF, dark: 0x2E1A00))
        case .purple:
            accent = Color(nsColor: .adaptive(light: 0x6E45C2, dark: 0xA98BFF))
            onAccent = Color(nsColor: .adaptive(light: 0xFFFFFF, dark: 0x1C0F3D))
        case .graphite:
            accent = Color(nsColor: .adaptive(light: 0x56565C, dark: 0xB0B0B6))
            onAccent = Color(nsColor: .adaptive(light: 0xFFFFFF, dark: 0x1C1C1E))
        }
    }

    public static func name(_ choice: AccentChoice, _ lang: Language) -> String {
        switch (choice, lang) {
        case (.system, .english): return "System"
        case (.system, .nepali): return "सिस्टम"
        case (.blue, .english): return "Blue"
        case (.blue, .nepali): return "नीलो"
        case (.teal, .english): return "Teal"
        case (.teal, .nepali): return "टिल"
        case (.green, .english): return "Green"
        case (.green, .nepali): return "हरियो"
        case (.marigold, .english): return "Marigold"
        case (.marigold, .nepali): return "सयपत्री"
        case (.purple, .english): return "Jacaranda"
        case (.purple, .nepali): return "जकरान्डा"
        case (.graphite, .english): return "Graphite"
        case (.graphite, .nepali): return "ग्राफाइट"
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
/// as colour: a red dot is a public holiday, a red ring a regional holiday, a grey dot a festival.
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
            case .festival: Circle().fill(Color.primary.opacity(0.45))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
