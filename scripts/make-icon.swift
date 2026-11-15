// Renders the app icon at 1024×1024 on the macOS icon grid.
// Usage: swift scripts/make-icon.swift out.png [concept]   (concept: dhaka; default dhaka)
import AppKit
import CoreText

let args = CommandLine.arguments
let out = args.count > 1 ? args[1] : "icon.png"
let concept = args.count > 2 ? args[2] : "dhaka"
let canvas: CGFloat = 1024

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: Int(canvas), height: Int(canvas), bitsPerComponent: 8, bytesPerRow: 0,
                    space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

/// The macOS icon silhouette: a continuous-curvature squircle (superellipse) on the 824 pt grid.
func squircle(in rect: CGRect, exponent n: CGFloat = 5) -> CGPath {
    let path = CGMutablePath()
    let a = rect.width / 2, b = rect.height / 2
    let steps = 720
    for i in 0...steps {
        let t = CGFloat(i) / CGFloat(steps) * 2 * .pi
        let c = cos(t), s = sin(t)
        let x = rect.midX + a * (c < 0 ? -1 : 1) * pow(abs(c), 2 / n)
        let y = rect.midY + b * (s < 0 ? -1 : 1) * pow(abs(s), 2 / n)
        i == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
    }
    path.closeSubpath()
    return path
}

let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
let shape = squircle(in: tile)

func fillTile(top: UInt32, bottom: UInt32) {
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: rgb(0x000000, 0.28))
    ctx.addPath(shape)
    ctx.setFillColor(rgb(bottom))
    ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(shape)
    ctx.clip()
    let g = CGGradient(colorsSpace: space, colors: [rgb(top), rgb(bottom)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: tile.maxY), end: CGPoint(x: 0, y: tile.minY), options: [])
    ctx.restoreGState()
}

/// Glyph outlines for a string, so placement uses true ink bounds.
func glyphPath(_ text: String, font name: String, size: CGFloat) -> CGPath {
    let font = CTFontCreateWithName(name as CFString, size, nil)
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
    ]))
    let path = CGMutablePath()
    for run in CTLineGetGlyphRuns(line) as! [CTRun] {
        let n = CTRunGetGlyphCount(run)
        var glyphs = [CGGlyph](repeating: 0, count: n)
        var positions = [CGPoint](repeating: .zero, count: n)
        CTRunGetGlyphs(run, CFRange(location: 0, length: n), &glyphs)
        CTRunGetPositions(run, CFRange(location: 0, length: n), &positions)
        for i in 0..<n {
            if let p = CTFontCreatePathForGlyph(font, glyphs[i], nil) {
                path.addPath(p, transform: CGAffineTransform(translationX: positions[i].x, y: positions[i].y))
            }
        }
    }
    return path
}

func draw(_ path: CGPath, centeredAt center: CGPoint, color: CGColor) {
    let b = path.boundingBoxOfPath
    var t = CGAffineTransform(translationX: center.x - b.midX, y: center.y - b.midY)
    ctx.addPath(path.copy(using: &t)!)
    ctx.setFillColor(color)
    ctx.fillPath()
}

func available(_ names: [String]) -> String {
    names.first { CTFontCopyPostScriptName(CTFontCreateWithName($0 as CFString, 12, nil)) as String == $0 } ?? names.last!
}

/// A lozenge as a path; `step` > 0 draws the stair-stepped edge a woven dhaka diamond has.
func lozenge(center c: CGPoint, radius r: CGFloat, step: CGFloat) -> CGPath {
    let path = CGMutablePath()
    guard step > 0 else {
        path.addLines(between: [CGPoint(x: c.x, y: c.y + r), CGPoint(x: c.x + r, y: c.y),
                                CGPoint(x: c.x, y: c.y - r), CGPoint(x: c.x - r, y: c.y)])
        path.closeSubpath()
        return path
    }
    let n = Int((r / step).rounded())
    var pts: [CGPoint] = []
    // Walk the four edges as stairs: top → right → bottom → left.
    for i in 0..<n { // top to right
        pts.append(CGPoint(x: c.x + CGFloat(i) * step, y: c.y + r - CGFloat(i) * step))
        pts.append(CGPoint(x: c.x + CGFloat(i + 1) * step, y: c.y + r - CGFloat(i) * step))
    }
    for i in 0..<n { // right to bottom
        pts.append(CGPoint(x: c.x + r - CGFloat(i) * step, y: c.y - CGFloat(i) * step))
        pts.append(CGPoint(x: c.x + r - CGFloat(i) * step, y: c.y - CGFloat(i + 1) * step))
    }
    for i in 0..<n { // bottom to left
        pts.append(CGPoint(x: c.x - CGFloat(i) * step, y: c.y - r + CGFloat(i) * step))
        pts.append(CGPoint(x: c.x - CGFloat(i + 1) * step, y: c.y - r + CGFloat(i) * step))
    }
    for i in 0..<n { // left to top
        pts.append(CGPoint(x: c.x - r + CGFloat(i) * step, y: c.y + CGFloat(i) * step))
        pts.append(CGPoint(x: c.x - r + CGFloat(i) * step, y: c.y + CGFloat(i + 1) * step))
    }
    path.addLines(between: pts)
    path.closeSubpath()
    return path
}

func fill(_ path: CGPath, _ color: CGColor) {
    ctx.addPath(path)
    ctx.setFillColor(color)
    ctx.fillPath()
}

switch concept {
case "dhaka":
    // Soft, deep tile; the motif is concentric rounded diamonds in madder, cotton and saffron.
    fillTile(top: 0x3A3048, bottom: 0x1B1624)
    let c = CGPoint(x: 512, y: 512)
    /// A diamond with softened corners: a smaller diamond stroked with a round join.
    func soft(_ radius: CGFloat, _ color: CGColor, shadow: Bool = false) {
        let round: CGFloat = 36
        let path = lozenge(center: c, radius: radius - round * 1.4142, step: 0)
        ctx.saveGState()
        if shadow { ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 40, color: CGColor(gray: 0, alpha: 0.45)) }
        ctx.addPath(path)
        ctx.setFillColor(color)
        ctx.setStrokeColor(color)
        ctx.setLineWidth(round * 2)
        ctx.setLineJoin(.round)
        ctx.drawPath(using: .fillStroke)
        ctx.restoreGState()
    }
    soft(330, rgb(0xC8162E), shadow: true)
    soft(236, rgb(0xF4EFE6))
    soft(206, rgb(0xF0A500))
    soft(92, rgb(0x1B1624))
    // A light edge along the top of the madder diamond, like glass catching light.
    ctx.saveGState()
    ctx.setStrokeColor(CGColor(gray: 1, alpha: 0.22))
    ctx.setLineWidth(5)
    ctx.setLineJoin(.round)
    ctx.addLines(between: [CGPoint(x: 512 - 258, y: 512 + 54), CGPoint(x: 512, y: 512 + 306 - 54 + 54), CGPoint(x: 512 + 258, y: 512 + 54)])
    ctx.strokePath()
    ctx.restoreGState()

case "tithi":
    fillTile(top: 0x1B3F8F, bottom: 0x0E2763)
    // Crescent: a disc with an offset disc removed, opening upward like the moon on the flag.
    let moon = CGMutablePath()
    let r: CGFloat = 250
    let c = CGPoint(x: 512, y: 470)
    moon.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
    ctx.saveGState()
    ctx.addPath(moon)
    ctx.addEllipse(in: CGRect(x: c.x - 232, y: c.y - 232 + 92, width: 464, height: 464))
    ctx.setFillColor(rgb(0xFFFFFF))
    ctx.fillPath(using: .evenOdd)
    ctx.restoreGState()
    // Sun, resting in the crescent.
    ctx.setFillColor(rgb(0xE8203F))
    ctx.fillEllipse(in: CGRect(x: 512 - 92, y: 560, width: 184, height: 184))

default:
    // A patro page: the macOS calendar-icon idiom, written in Nepali.
    fillTile(top: 0xFFFFFF, bottom: 0xF1F1F4)
    let medium = available(["KohinoorDevanagari-Medium", "KohinoorDevanagari-Regular", "DevanagariSangamMN"])
    let light = available(["KohinoorDevanagari-Light", "KohinoorDevanagari-Regular", "DevanagariSangamMN"])
    draw(glyphPath("बैशाख", font: medium, size: 118), centeredAt: CGPoint(x: 512, y: 752), color: rgb(0xD0142F))
    draw(glyphPath("१", font: light, size: 600), centeredAt: CGPoint(x: 512, y: 412), color: rgb(0x1D1D1F))
}

let png = NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: out))
print("wrote \(out) (\(concept))")
