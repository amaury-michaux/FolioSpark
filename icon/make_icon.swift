// Generates the FolioSpark macOS icon at all required sizes.
// Run from the project root: swift icon/make_icon.swift
import AppKit

let canvas = NSRect(x: 100, y: 100, width: 824, height: 824)

func shadow(blur: CGFloat, offset: CGFloat, opacity: CGFloat, draw: () -> Void) {
    NSGraphicsContext.saveGraphicsState()
    let effect = NSShadow()
    effect.shadowColor = .black.withAlphaComponent(opacity)
    effect.shadowBlurRadius = blur
    effect.shadowOffset = NSSize(width: 0, height: offset)
    effect.set()
    draw()
    NSGraphicsContext.restoreGraphicsState()
}

let image = NSImage(size: NSSize(width: 1024, height: 1024), flipped: false) { _ in
    let tile = NSBezierPath(roundedRect: canvas, xRadius: 188, yRadius: 188)
    shadow(blur: 26, offset: -12, opacity: 0.25) {
        NSColor.black.setFill()
        tile.fill()
    }
    NSGradient(starting: NSColor(srgbRed: 0.34, green: 0.22, blue: 0.91, alpha: 1),
               ending: NSColor(srgbRed: 0.05, green: 0.51, blue: 0.95, alpha: 1))!
        .draw(in: tile, angle: -45)

    // A vivid diagonal page, legible at Finder icon sizes.
    NSGraphicsContext.saveGraphicsState()
    let transform = NSAffineTransform()
    transform.translateX(by: 505, yBy: 515)
    transform.rotate(byDegrees: -9)
    transform.concat()
    let page = NSBezierPath(roundedRect: NSRect(x: -220, y: -292, width: 440, height: 584), xRadius: 33, yRadius: 33)
    shadow(blur: 30, offset: -17, opacity: 0.30) {
        NSColor.white.setFill()
        page.fill()
    }
    NSColor(srgbRed: 0.91, green: 0.94, blue: 1, alpha: 1).setFill()
    for (y, width) in [(130.0, 245.0), (68.0, 300.0), (6.0, 266.0), (-56.0, 215.0)] {
        NSBezierPath(roundedRect: NSRect(x: -154, y: y, width: width, height: 23), xRadius: 12, yRadius: 12).fill()
    }
    NSGraphicsContext.restoreGraphicsState()

    // Spark mark: four sharply drawn points with a warm center.
    let spark = NSBezierPath()
    let cx: CGFloat = 700, cy: CGFloat = 340
    let points: [NSPoint] = [
        .init(x: cx, y: cy + 155), .init(x: cx + 32, y: cy + 35),
        .init(x: cx + 145, y: cy), .init(x: cx + 32, y: cy - 35),
        .init(x: cx, y: cy - 150), .init(x: cx - 32, y: cy - 35),
        .init(x: cx - 145, y: cy), .init(x: cx - 32, y: cy + 35)
    ]
    spark.move(to: points[0])
    points.dropFirst().forEach { spark.line(to: $0) }
    spark.close()
    shadow(blur: 20, offset: -8, opacity: 0.25) {
        NSColor(srgbRed: 1, green: 0.75, blue: 0.22, alpha: 1).setFill()
        spark.fill()
    }
    return true
}

func png(_ pixels: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

func bigEndian(_ value: Int) -> [UInt8] {
    let value = UInt32(value)
    return [UInt8((value >> 24) & 0xff), UInt8((value >> 16) & 0xff),
            UInt8((value >> 8) & 0xff), UInt8(value & 0xff)]
}

let sizes: [(String, Int)] = [
    ("icp4", 16), ("icp5", 32), ("icp6", 64), ("ic07", 128),
    ("ic08", 256), ("ic09", 512), ("ic10", 1024)
]
var entries = Data()
for (type, pixels) in sizes {
    let content = png(pixels)
    entries.append(contentsOf: type.utf8)
    entries.append(contentsOf: bigEndian(content.count + 8))
    entries.append(content)
    if pixels == 1024 { try! content.write(to: URL(fileURLWithPath: "icon/AppIcon.png")) }
}
var icns = Data("icns".utf8)
icns.append(contentsOf: bigEndian(entries.count + 8))
icns.append(entries)
try! icns.write(to: URL(fileURLWithPath: "icon/AppIcon.icns"))
print("OK → icon/AppIcon.icns")
