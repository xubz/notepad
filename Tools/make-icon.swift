// Renders the app icon (a Tango-colored notepad) into an .iconset folder.
// Usage: swift Tools/make-icon.swift <output.iconset>
import AppKit

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Notepad.iconset"
try FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

func hex(_ v: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255,
            blue: CGFloat(v & 0xFF) / 255, alpha: a)
}

func render(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: px, height: px)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let k = CGFloat(px) / 1024
    func R(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSRect {
        NSRect(x: x * k, y: y * k, width: w * k, height: h * k)
    }

    let body = R(100, 100, 824, 824)
    let page = NSBezierPath(roundedRect: body, xRadius: 185 * k, yRadius: 185 * k)

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
    shadow.shadowBlurRadius = 24 * k
    shadow.shadowOffset = NSSize(width: 0, height: -10 * k)
    shadow.set()
    hex(0xFFFFFF).setFill()
    page.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    page.addClip()
    NSGradient(starting: hex(0xFFFFFF), ending: hex(0xEEEEEC))!.draw(in: body, angle: -90)

    // Binding band (Tango sky blue) with ring holes
    NSGradient(starting: hex(0x3465A4), ending: hex(0x204A87))!.draw(in: R(100, 764, 824, 160), angle: -90)
    for i in 0..<6 {
        let cx = 196 + CGFloat(i) * 126.4
        hex(0xFFFFFF, 0.92).setFill()
        NSBezierPath(ovalIn: R(cx - 20, 824, 40, 40)).fill()
    }

    // Ruled lines + margin
    hex(0x729FCF, 0.45).setFill()
    for i in 0..<9 { R(100, 690 - CGFloat(i) * 66, 824, 5).fill() }
    hex(0xEF2929, 0.7).setFill()
    R(232, 100, 6, 664).fill()

    // "Code" written on the lines, in Tango syntax colors
    let bars: [(CGFloat, CGFloat, UInt32)] = [
        (270, 150, 0x204A87), (440, 220, 0x5C3566),
        (310, 300, 0x8F5902),
        (310, 130, 0x204A87), (460, 260, 0x4E9A06),
        (310, 340, 0x888A85),
        (270, 110, 0x204A87), (400, 90, 0xCE5C00),
    ]
    let rows = [0, 0, 1, 2, 2, 3, 4, 4]
    for (bar, row) in zip(bars, rows) {
        let y = 690 - CGFloat(row) * 66 + 14
        hex(bar.2).setFill()
        NSBezierPath(roundedRect: R(bar.0, y, bar.1, 30), xRadius: 15 * k, yRadius: 15 * k).fill()
    }
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let sizes: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32), ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256), ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for (name, px) in sizes {
    try render(px).write(to: URL(fileURLWithPath: "\(outDir)/\(name).png"))
}
print("Wrote \(sizes.count) images to \(outDir)")
