// Draws Flickbar's app icon and writes Resources/AppIcon.icns. Run: scripts/make-icon.sh
import AppKit

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat(hex >> 16 & 0xff) / 255, green: CGFloat(hex >> 8 & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255, alpha: alpha)
}

/// Draws on a 1024×1024 canvas, origin bottom-left, following the macOS icon grid (824pt body).
func draw(_ c: CGContext) {
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let bodyPath = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)

    // Body with a soft drop shadow and a blue-to-indigo gradient.
    c.saveGState()
    c.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: color(0x000000, 0.3))
    c.addPath(bodyPath); c.setFillColor(color(0x3a47d5)); c.fillPath()
    c.restoreGState()
    c.saveGState()
    c.addPath(bodyPath); c.clip()
    let gradient = CGGradient(colorsSpace: nil, colors: [color(0x5aa2ff), color(0x3a47d5)] as CFArray, locations: [0, 1])!
    c.drawLinearGradient(gradient, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])

    // Desktop panel.
    let desk = CGRect(x: 190, y: 250, width: 644, height: 470)
    c.addPath(CGPath(roundedRect: desk, cornerWidth: 44, cornerHeight: 44, transform: nil))
    c.setFillColor(color(0xffffff, 0.16)); c.fillPath()

    // Where the window came from: dashed outline on the right half.
    let ghost = CGRect(x: desk.midX + 14, y: desk.minY + 28, width: desk.width / 2 - 42, height: desk.height - 56)
    c.addPath(CGPath(roundedRect: ghost, cornerWidth: 26, cornerHeight: 26, transform: nil))
    c.setStrokeColor(color(0xffffff, 0.55)); c.setLineWidth(10); c.setLineDash(phase: 0, lengths: [26, 18])
    c.strokePath()
    c.setLineDash(phase: 0, lengths: [])

    // The snapped window on the left half.
    let win = CGRect(x: desk.minX + 28, y: desk.minY + 28, width: desk.width / 2 - 42, height: desk.height - 56)
    let winPath = CGPath(roundedRect: win, cornerWidth: 26, cornerHeight: 26, transform: nil)
    c.saveGState()
    c.setShadow(offset: CGSize(width: 0, height: -8), blur: 20, color: color(0x101a6b, 0.35))
    c.addPath(winPath); c.setFillColor(color(0xffffff)); c.fillPath()
    c.restoreGState()
    // Title bar strip and traffic lights.
    c.saveGState()
    c.addPath(winPath); c.clip()
    c.setFillColor(color(0xe8ecf7)); c.fill(CGRect(x: win.minX, y: win.maxY - 64, width: win.width, height: 64))
    c.restoreGState()
    for (i, hex) in [0xff5f57, 0xfebc2e, 0x28c840].enumerated() {
        c.setFillColor(color(UInt32(hex)))
        c.fillEllipse(in: CGRect(x: win.minX + 26 + CGFloat(i) * 34, y: win.maxY - 44, width: 22, height: 22))
    }
    // Content lines.
    c.setFillColor(color(0xd5dbee))
    for (i, w) in [0.72, 0.55, 0.64, 0.4].enumerated() {
        c.fill(CGRect(x: win.minX + 28, y: win.maxY - 116 - CGFloat(i) * 46, width: (win.width - 56) * w, height: 18))
    }

    // Two fingertips on the title bar, with a motion trail toward the right edge.
    let tipY = win.maxY - 32
    let trail = CGGradient(colorsSpace: nil, colors: [color(0xffffff, 0.0), color(0xffffff, 0.85)] as CFArray, locations: [0, 1])!
    let tipX = win.maxX - 70
    for dy: CGFloat in [-36, 36] {
        let y = tipY + dy
        c.saveGState()
        c.addPath(CGPath(roundedRect: CGRect(x: tipX, y: y - 11, width: 300, height: 22), cornerWidth: 11, cornerHeight: 11, transform: nil))
        c.clip()
        c.drawLinearGradient(trail, start: CGPoint(x: tipX + 300, y: y), end: CGPoint(x: tipX, y: y), options: [])
        c.restoreGState()
        c.saveGState()
        c.setShadow(offset: CGSize(width: 0, height: -4), blur: 14, color: color(0x101a6b, 0.45))
        c.setFillColor(color(0xffffff))
        c.fillEllipse(in: CGRect(x: tipX - 28, y: y - 28, width: 56, height: 56))
        c.restoreGState()
    }
    c.restoreGState()
}

func png(size: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    ctx.cgContext.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    draw(ctx.cgContext)
    ctx.flushGraphics()
    return rep.representation(using: .png, properties: [:])!
}

let iconset = URL(fileURLWithPath: CommandLine.arguments[1])
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try! png(size: base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try! png(size: base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
