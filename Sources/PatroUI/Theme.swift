import SwiftUI
import PatroCore

public extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

public struct Theme: Identifiable, Hashable, Sendable {
    public let id: String
    public let nameEn: String
    public let nameNe: String
    public let isDark: Bool
    public let backgroundTop: Color
    public let backgroundBottom: Color
    public let card: Color
    public let primary: Color
    public let secondary: Color
    public let accent: Color
    public let onAccent: Color
    public let holiday: Color
    public let festival: Color

    public func name(_ lang: Language) -> String { lang == .nepali ? nameNe : nameEn }

    public var background: LinearGradient {
        LinearGradient(colors: [backgroundTop, backgroundBottom], startPoint: .top, endPoint: .bottom)
    }

    public var colorScheme: ColorScheme { isDark ? .dark : .light }

    public static let light = Theme(
        id: "light", nameEn: "Light", nameNe: "उज्यालो", isDark: false,
        backgroundTop: Color(hex: 0xFFFFFF), backgroundBottom: Color(hex: 0xF6F6F8),
        card: Color(hex: 0x000000, opacity: 0.04), primary: Color(hex: 0x1D1D1F), secondary: Color(hex: 0x6E6E73),
        accent: Color(hex: 0xDC143C), onAccent: .white, holiday: Color(hex: 0xD70F2D), festival: Color(hex: 0x003893))

    public static let dark = Theme(
        id: "dark", nameEn: "Dark", nameNe: "अँध्यारो", isDark: true,
        backgroundTop: Color(hex: 0x232326), backgroundBottom: Color(hex: 0x1A1A1C),
        card: Color(hex: 0xFFFFFF, opacity: 0.06), primary: Color(hex: 0xF5F5F7), secondary: Color(hex: 0x98989D),
        accent: Color(hex: 0xFF375F), onAccent: .white, holiday: Color(hex: 0xFF5A6E), festival: Color(hex: 0x6EA8FF))

    public static let himalaya = Theme(
        id: "himalaya", nameEn: "Himalaya", nameNe: "हिमालय", isDark: false,
        backgroundTop: Color(hex: 0xDCEBFA), backgroundBottom: Color(hex: 0xFDFEFF),
        card: Color(hex: 0x003893, opacity: 0.06), primary: Color(hex: 0x0B2545), secondary: Color(hex: 0x4F6D8F),
        accent: Color(hex: 0x003893), onAccent: .white, holiday: Color(hex: 0xC8102E), festival: Color(hex: 0x1F6FEB))

    public static let laliguras = Theme(
        id: "laliguras", nameEn: "Laliguras", nameNe: "लालीगुराँस", isDark: false,
        backgroundTop: Color(hex: 0xFFE4E9), backgroundBottom: Color(hex: 0xFFF8F5),
        card: Color(hex: 0xC8102E, opacity: 0.06), primary: Color(hex: 0x3B0A14), secondary: Color(hex: 0x8A4B57),
        accent: Color(hex: 0xC8102E), onAccent: .white, holiday: Color(hex: 0xC8102E), festival: Color(hex: 0x2E7D32))

    public static let midnight = Theme(
        id: "midnight", nameEn: "Midnight", nameNe: "मध्यरात", isDark: true,
        backgroundTop: Color(hex: 0x111833), backgroundBottom: Color(hex: 0x0A0F22),
        card: Color(hex: 0xFFFFFF, opacity: 0.07), primary: Color(hex: 0xEEF1FF), secondary: Color(hex: 0x9AA3C7),
        accent: Color(hex: 0xF4C430), onAccent: Color(hex: 0x111833), holiday: Color(hex: 0xFF6B81), festival: Color(hex: 0x7FB3FF))

    public static let dhaka = Theme(
        id: "dhaka", nameEn: "Dhaka", nameNe: "ढाका", isDark: true,
        backgroundTop: Color(hex: 0x5E1218), backgroundBottom: Color(hex: 0x3A0A0F),
        card: Color(hex: 0xFFFFFF, opacity: 0.08), primary: Color(hex: 0xFFF3E6), secondary: Color(hex: 0xE3B9A8),
        accent: Color(hex: 0xF2C14E), onAccent: Color(hex: 0x3A0A0F), holiday: Color(hex: 0xFFB4A2), festival: Color(hex: 0x9FD8CB))

    public static let forest = Theme(
        id: "forest", nameEn: "Chitwan", nameNe: "चितवन", isDark: false,
        backgroundTop: Color(hex: 0xE3F1E4), backgroundBottom: Color(hex: 0xFAFCF7),
        card: Color(hex: 0x1B5E20, opacity: 0.06), primary: Color(hex: 0x12301A), secondary: Color(hex: 0x557A5E),
        accent: Color(hex: 0x2E7D32), onAccent: .white, holiday: Color(hex: 0xC62828), festival: Color(hex: 0x8D6E00))

    /// All selectable themes. "system" follows the Mac's appearance.
    public static let all: [Theme] = [light, dark, himalaya, laliguras, forest, midnight, dhaka]

    public static func resolve(_ id: String, systemIsDark: Bool) -> Theme {
        if id == "system" { return systemIsDark ? dark : light }
        return all.first { $0.id == id } ?? (systemIsDark ? dark : light)
    }
}
