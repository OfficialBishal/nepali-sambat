// Renders the app icon at 1024×1024. Usage: swift scripts/make-icon.swift out.png
import AppKit
import CoreText

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"
let size: CGFloat = 1024

func color(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
                    space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

// macOS icon grid: 824pt squircle centred in 1024 with room for the shadow.
let inset: CGFloat = 100
let tile = CGRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset)
let tilePath = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: color(0x000000, 0.35))
ctx.addPath(tilePath)
ctx.setFillColor(color(0xC8102E))
ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(tilePath)
ctx.clip()
let bg = CGGradient(colorsSpace: cs, colors: [color(0xF0354F), color(0xB30C27), color(0x8E0A20)] as CFArray, locations: [0, 0.6, 1])!
ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: tile.maxY), end: CGPoint(x: 0, y: tile.minY), options: [])

// Faint Himalayan ridge across the tile.
let ridge = CGMutablePath()
ridge.move(to: CGPoint(x: tile.minX, y: tile.minY + 170))
let peaks: [(CGFloat, CGFloat)] = [(0.12, 250), (0.22, 200), (0.36, 330), (0.47, 240), (0.6, 380), (0.72, 260), (0.84, 320), (1.0, 210)]
for (fx, h) in peaks { ridge.addLine(to: CGPoint(x: tile.minX + tile.width * fx, y: tile.minY + h)) }
ridge.addLine(to: CGPoint(x: tile.maxX, y: tile.minY))
ridge.addLine(to: CGPoint(x: tile.minX, y: tile.minY))
ridge.closeSubpath()
ctx.addPath(ridge)
ctx.setFillColor(color(0xFFFFFF, 0.08))
ctx.fillPath()
ctx.restoreGState()

// Calendar page.
let page = CGRect(x: 262, y: 218, width: 500, height: 540)
let pagePath = CGPath(roundedRect: page, cornerWidth: 70, cornerHeight: 70, transform: nil)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 30, color: color(0x3A0008, 0.45))
ctx.addPath(pagePath)
ctx.setFillColor(color(0xFFFFFF))
ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(pagePath)
ctx.clip()
let header = CGRect(x: page.minX, y: page.maxY - 150, width: page.width, height: 150)
let hg = CGGradient(colorsSpace: cs, colors: [color(0x1D4FB8), color(0x003893)] as CFArray, locations: [0, 1])!
ctx.saveGState()
ctx.clip(to: header)
ctx.drawLinearGradient(hg, start: CGPoint(x: 0, y: header.maxY), end: CGPoint(x: 0, y: header.minY), options: [])
ctx.restoreGState()
ctx.restoreGState()

// Binding rings.
for x in [page.minX + 135, page.maxX - 135] {
    let ring = CGRect(x: x - 26, y: page.maxY - 60, width: 52, height: 110)
    ctx.addPath(CGPath(roundedRect: ring, cornerWidth: 26, cornerHeight: 26, transform: nil))
    ctx.setFillColor(color(0xF4F5F8))
    ctx.fillPath()
    ctx.addPath(CGPath(roundedRect: ring.insetBy(dx: 10, dy: 10), cornerWidth: 16, cornerHeight: 16, transform: nil))
    ctx.setFillColor(color(0xC9CED8))
    ctx.fillPath()
}

// Devanagari numeral, drawn as an outline and centred in the white part of the page.
func draw(_ text: String, fontName: String, size: CGFloat, color c: CGColor, in box: CGRect) {
    let font = CTFontCreateWithName(fontName as CFString, size, nil)
    let attr = NSAttributedString(string: text, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font])
    let line = CTLineCreateWithAttributedString(attr)
    let combined = CGMutablePath()
    for run in CTLineGetGlyphRuns(line) as! [CTRun] {
        let count = CTRunGetGlyphCount(run)
        var glyphs = [CGGlyph](repeating: 0, count: count)
        var positions = [CGPoint](repeating: .zero, count: count)
        CTRunGetGlyphs(run, CFRange(location: 0, length: count), &glyphs)
        CTRunGetPositions(run, CFRange(location: 0, length: count), &positions)
        for i in 0..<count {
            if let p = CTFontCreatePathForGlyph(font, glyphs[i], nil) {
                combined.addPath(p, transform: CGAffineTransform(translationX: positions[i].x, y: positions[i].y))
            }
        }
    }
    let b = combined.boundingBoxOfPath
    var t = CGAffineTransform(translationX: box.midX - b.midX, y: box.midY - b.midY)
    ctx.addPath(combined.copy(using: &t)!)
    ctx.setFillColor(c)
    ctx.fillPath()
}

let glyphFont = ["KohinoorDevanagari-Semibold", "DevanagariSangamMN-Bold", "ITFDevanagari-Bold"]
    .first { CTFontCopyPostScriptName(CTFontCreateWithName($0 as CFString, 12, nil)) as String == $0 } ?? "DevanagariSangamMN-Bold"
draw("१", fontName: glyphFont, size: 340, color: color(0xC8102E),
     in: CGRect(x: page.minX, y: page.minY, width: page.width, height: page.height - 150))

let png = NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: out))
print("wrote \(out) using \(glyphFont)")
