// Renders the app icon at 1024×1024 on the macOS icon grid.
// Usage: swift scripts/make-icon.swift out.png [concept]   (concept: pad | pad-sand | pad-brick | pad-blue; default pad)
import AppKit
import CoreText

let args = CommandLine.arguments
let out = args.count > 1 ? args[1] : "icon.png"
let concept = args.count > 2 ? args[2] : "pad"
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

func roundedRect(_ r: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: r, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

/// A patro page: a sheet with a coloured header carrying the month, and the day in large type.
/// A second sheet peeks out underneath, so it reads as a pad you tear pages from.
func patroPage(tileTop: UInt32, tileBottom: UInt32, band: UInt32, numeral: UInt32) {
    fillTile(top: tileTop, bottom: tileBottom)
    let medium = available(["KohinoorDevanagari-Semibold", "KohinoorDevanagari-Medium", "DevanagariSangamMN"])
    let regular = available(["KohinoorDevanagari-Regular", "DevanagariSangamMN"])
    let page = CGRect(x: 242, y: 214, width: 540, height: 588)
    let radius: CGFloat = 64

    ctx.saveGState()
    ctx.addPath(shape)
    ctx.clip()
    // The sheet underneath.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -8), blur: 18, color: rgb(0x000000, 0.22))
    ctx.addPath(roundedRect(page.insetBy(dx: 26, dy: 0).offsetBy(dx: 0, dy: -26), radius))
    ctx.setFillColor(rgb(0xE9E6EE))
    ctx.fillPath()
    ctx.restoreGState()
    // The page, with a soft drop shadow.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 34, color: rgb(0x000000, 0.30))
    ctx.addPath(roundedRect(page, radius))
    ctx.setFillColor(rgb(0xFFFFFF))
    ctx.fillPath()
    ctx.restoreGState()
    // Header band, clipped to the page's rounded top.
    ctx.saveGState()
    ctx.addPath(roundedRect(page, radius))
    ctx.clip()
    let bandRect = CGRect(x: page.minX, y: page.maxY - 158, width: page.width, height: 158)
    let g = CGGradient(colorsSpace: space, colors: [rgb(band), rgb(band, 0.92)] as CFArray, locations: [0, 1])!
    ctx.addRect(bandRect)
    ctx.clip()
    ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: bandRect.maxY), end: CGPoint(x: 0, y: bandRect.minY), options: [])
    ctx.restoreGState()
    draw(glyphPath("बैशाख", font: medium, size: 92), centeredAt: CGPoint(x: page.midX, y: page.maxY - 79), color: rgb(0xFFFFFF))
    draw(glyphPath("१", font: regular, size: 430), centeredAt: CGPoint(x: page.midX, y: page.minY + 218), color: rgb(numeral))
    ctx.restoreGState()
}

switch concept {
case "pad-sand":
    patroPage(tileTop: 0xEFE6D6, tileBottom: 0xD9C8AC, band: 0xB8342E, numeral: 0x1C1C22)
case "pad-brick":
    patroPage(tileTop: 0xC9473F, tileBottom: 0x9E2A25, band: 0x2A2A30, numeral: 0x1C1C22)
case "pad-blue":
    patroPage(tileTop: 0x3D63C9, tileBottom: 0x1C3C93, band: 0xD0142F, numeral: 0x1C1C22)
default:
    // Graphite tile, brick-red header: the app's own palette of neutral greys and holiday red.
    patroPage(tileTop: 0x4A4A51, tileBottom: 0x232327, band: 0xB8342E, numeral: 0x1C1C22)
}

let png = NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: out))
print("wrote \(out) (\(concept))")
