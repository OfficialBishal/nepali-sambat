import AppKit
import SambatCore
import SwiftUI

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }

    /// A colour that resolves differently in light and dark appearances.
    static func adaptive(light: UInt32, dark: UInt32) -> NSColor {
        NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(hex: dark) : NSColor(hex: light)
        }
    }
}

/// The palette, taken from dhaka thread colours. Each has one job and nothing else gets colour.
public enum Loom {
    /// Ink for text drawn on saffron.
    public static let ink = Color(nsColor: NSColor(hex: 0x1C1724))

    /// Holidays and Saturdays, red as a patro prints them (madder thread).
    public static let madder = Color(nsColor: .adaptive(light: 0xC0122C, dark: 0xFF6B70))
    /// A wash of madder behind a holiday numeral.
    public static let madderWash = Color(nsColor: .adaptive(light: 0xF6D5D9, dark: 0x5A2229))
    /// Today and the current selection (saffron thread).
    public static let saffron = Color(nsColor: NSColor(hex: 0xF0A500))
    /// Festivals that are not holidays (jamara green).
    public static let jamara = Color(nsColor: .adaptive(light: 0x2C7A4B, dark: 0x5CC98A))
}

public extension ShapeStyle where Self == Color {
    /// Small supporting text. System secondary grey falls under 4.5:1 at caption sizes;
    /// this keeps small text readable on both appearances.
    static var quiet: Color { Color.primary.opacity(0.68) }
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

/// A square turned on its point with softened corners: the small marker shape used for festivals.
public struct Lozenge: InsettableShape {
    var inset: CGFloat = 0

    public init() {}

    public func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: inset, dy: inset)
        let points = [CGPoint(x: r.midX, y: r.minY), CGPoint(x: r.maxX, y: r.midY),
                      CGPoint(x: r.midX, y: r.maxY), CGPoint(x: r.minX, y: r.midY)]
        let soften = min(r.width, r.height) * 0.16
        var path = Path()
        for i in 0..<4 {
            let p = points[i], next = points[(i + 1) % 4], prev = points[(i + 3) % 4]
            let a = interpolate(p, prev, soften / distance(p, prev))
            let b = interpolate(p, next, soften / distance(p, next))
            if i == 0 { path.move(to: a) } else { path.addLine(to: a) }
            path.addQuadCurve(to: b, control: p)
        }
        path.closeSubpath()
        return path
    }

    public func inset(by amount: CGFloat) -> Lozenge {
        var copy = self
        copy.inset += amount
        return copy
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat { max(0.001, hypot(a.x - b.x, a.y - b.y)) }
    private func interpolate(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
        CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
    }
}

/// The soft rounded square that marks a day: Nepal's today, the selection, a holiday.
public struct DayMark: InsettableShape {
    var inset: CGFloat = 0

    public init() {}

    public func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: inset, dy: inset)
        return RoundedRectangle(cornerRadius: min(r.width, r.height) * 0.34, style: .continuous).path(in: r)
    }

    public func inset(by amount: CGFloat) -> DayMark {
        var copy = self
        copy.inset += amount
        return copy
    }
}

/// The lunar month as a scale of thirty ticks in two fortnights: tithis already past are filled,
/// today's is saffron and taller, the rest are faint.
public struct TithiBand: View {
    let tithi: Int
    let lang: Language
    var height: CGFloat
    var animated: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var shown = State(initialValue: false)

    public init(tithi: Int, lang: Language, height: CGFloat = 14, animated: Bool = false) {
        self.tithi = tithi
        self.lang = lang
        self.height = height
        self.animated = animated
    }

    public var body: some View {
        GeometryReader { geo in
            let gap = max(6, height * 0.6)
            let slot = (geo.size.width - gap) / 30
            HStack(spacing: 0) {
                ForEach(1...15, id: \.self) { tick($0, slot: slot) }
                Color.clear.frame(width: gap, height: 1)
                ForEach(16...30, id: \.self) { tick($0, slot: slot) }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(height: height)
        .onAppear {
            guard animated, !reduceMotion else { shown.wrappedValue = true; return }
            shown.wrappedValue = false
            DispatchQueue.main.async { shown.wrappedValue = true }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    @ViewBuilder
    private func tick(_ i: Int, slot: CGFloat) -> some View {
        let visible = shown.wrappedValue || !animated
        let isToday = i == tithi
        let major = i == 15 || i == 30
        Capsule()
            .fill(isToday ? AnyShapeStyle(Loom.saffron) : AnyShapeStyle(Color.primary.opacity(i < tithi ? 0.55 : 0.16)))
            .frame(width: max(2, slot * (isToday ? 0.62 : 0.5)),
                   height: height * (isToday ? 1 : (major ? 0.78 : 0.58)))
            .frame(width: slot, height: height)
            .scaleEffect(y: visible ? 1 : 0.2)
            .opacity(visible ? 1 : 0)
            .animation(reduceMotion || !animated ? nil : .spring(duration: 0.45, bounce: 0.2).delay(Double(i) * 0.01), value: visible)
    }

    private var accessibilityText: String {
        let paksha = tithi <= 15 ? (lang == .nepali ? "शुक्ल पक्ष" : "bright fortnight") : (lang == .nepali ? "कृष्ण पक्ष" : "dark fortnight")
        let day = tithi <= 15 ? tithi : tithi - 15
        return lang == .nepali ? "\(paksha), \(Formatter.digits(day, .nepali)) औं तिथि" : "Day \(day) of 15 in the \(paksha)"
    }
}

/// The one festival marker used everywhere. Fill carries the meaning as well as colour:
/// filled = public holiday, half filled = regional holiday, outline = festival.
public struct EventMarker: View {
    public enum Kind: Sendable { case publicHoliday, regionalHoliday, festival }

    let kind: Kind
    let size: CGFloat

    public init(_ kind: Kind, size: CGFloat = 7, onField: Bool = false) {
        self.kind = kind
        self.size = size
    }

    public static func kind(for events: [CalendarEvent]) -> Kind? {
        if events.contains(where: { $0.category == .publicHoliday }) { return .publicHoliday }
        if events.contains(where: { $0.category == .regionalHoliday }) { return .regionalHoliday }
        if events.contains(where: { $0.category == .festival }) { return .festival }
        return nil
    }

    public static func kind(for event: CalendarEvent) -> Kind? { kind(for: [event]) }

    public var body: some View {
        let red = Loom.madder
        let green = Loom.jamara
        let line = max(1, size * 0.18)
        Group {
            switch kind {
            case .publicHoliday:
                Lozenge().fill(red)
            case .regionalHoliday:
                ZStack {
                    Lozenge().fill(red)
                        .mask(Rectangle().frame(width: size / 2).frame(maxWidth: .infinity, alignment: .leading))
                    Lozenge().strokeBorder(red, lineWidth: line)
                }
            case .festival:
                Lozenge().strokeBorder(green, lineWidth: line)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
