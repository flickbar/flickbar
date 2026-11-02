// Draws the disk image's window background: swift scripts/dmg-background.swift out.png out@2x.png
// 600×400 points; the app icon sits at (150, 200) and the Applications folder at (450, 200) (see dmg.sh).
import AppKit

let size = NSSize(width: 600, height: 400)
let accent = NSColor(srgbRed: 0.27, green: 0.45, blue: 1, alpha: 1)
let violet = NSColor(srgbRed: 0.62, green: 0.42, blue: 1, alpha: 1)

/// Points measured from the top, as Finder positions icons.
func top(_ x: CGFloat, _ y: CGFloat) -> NSPoint { NSPoint(x: x, y: size.height - y) }

func glow(_ color: NSColor, at center: NSPoint, radius: CGFloat) {
    NSGradient(starting: color, ending: color.withAlphaComponent(0))!
        .draw(fromCenter: center, radius: 0, toCenter: center, radius: radius, options: [])
}

func text(_ string: String, y: CGFloat, font: NSFont, color: NSColor, kern: CGFloat = 0) {
    let style = NSMutableParagraphStyle()
    style.alignment = .center
    NSAttributedString(string: string, attributes: [.font: font, .foregroundColor: color, .paragraphStyle: style, .kern: kern])
        .draw(in: NSRect(x: 0, y: size.height - y - font.pointSize * 1.3, width: size.width, height: font.pointSize * 1.6))
}

func render(scale: CGFloat, to path: String) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = size
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // Finder draws its icon labels dark, so the window stays light.
    NSGradient(starting: NSColor(srgbRed: 0.97, green: 0.98, blue: 1, alpha: 1),
               ending: NSColor(srgbRed: 0.90, green: 0.92, blue: 0.99, alpha: 1))!
        .draw(in: NSRect(origin: .zero, size: size), angle: -90)
    glow(accent.withAlphaComponent(0.30), at: top(40, 30), radius: 330)
    glow(violet.withAlphaComponent(0.26), at: top(580, 400), radius: 340)
    glow(NSColor.white.withAlphaComponent(0.7), at: top(300, 210), radius: 220)

    // Frosted panels under each icon and its label.
    for x: CGFloat in [150, 450] {
        let panel = NSBezierPath(roundedRect: NSRect(x: x - 82, y: size.height - 290, width: 164, height: 176), xRadius: 26, yRadius: 26)
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor(srgbRed: 0.2, green: 0.25, blue: 0.5, alpha: 0.18)
        shadow.shadowBlurRadius = 24
        shadow.shadowOffset = NSSize(width: 0, height: -8)
        shadow.set()
        NSColor.white.withAlphaComponent(0.6).setFill()
        panel.fill()
        NSGraphicsContext.restoreGraphicsState()
        NSColor.white.withAlphaComponent(0.9).setStroke()
        panel.lineWidth = 1.5
        panel.stroke()
    }

    // A dashed arc from the app over to Applications, ending in a solid head.
    let arc = NSBezierPath()
    arc.move(to: top(246, 196))
    arc.curve(to: top(350, 186), controlPoint1: top(275, 140), controlPoint2: top(322, 160))
    arc.lineWidth = 5
    arc.lineCapStyle = .round
    arc.setLineDash([2, 11], count: 2, phase: 0)
    accent.setStroke()
    arc.stroke()
    // The head points along the curve's last tangent (from the second control point to the end).
    let end = top(350, 186), dx: CGFloat = 350 - 322, dy: CGFloat = 160 - 186, length = (dx * dx + dy * dy).squareRoot()
    let (ux, uy) = (dx / length, dy / length)
    let head = NSBezierPath()
    head.move(to: NSPoint(x: end.x + ux * 22, y: end.y + uy * 22))
    head.line(to: NSPoint(x: end.x - uy * 10, y: end.y + ux * 10))
    head.line(to: NSPoint(x: end.x + uy * 10, y: end.y - ux * 10))
    head.close()
    head.lineJoinStyle = .round
    head.lineWidth = 4
    violet.setFill()
    violet.setStroke()
    head.fill()
    head.stroke()

    text("INSTALL FLICKBAR", y: 34, font: .systemFont(ofSize: 11, weight: .bold), color: accent, kern: 2.5)
    text("Drag to Applications", y: 52, font: .systemFont(ofSize: 26, weight: .bold), color: NSColor(srgbRed: 0.1, green: 0.12, blue: 0.2, alpha: 1))
    text("Then open Flickbar from your Applications folder.", y: 322, font: .systemFont(ofSize: 13, weight: .medium),
         color: NSColor(srgbRed: 0.35, green: 0.38, blue: 0.5, alpha: 1))
    text("Snap windows with a flick of the title bar", y: 362, font: .systemFont(ofSize: 11),
         color: NSColor(srgbRed: 0.5, green: 0.53, blue: 0.65, alpha: 1))

    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

render(scale: 1, to: CommandLine.arguments[1])
render(scale: 2, to: CommandLine.arguments[2])
