import AppKit

/// A translucent rounded rectangle showing where the window will land, shown while the fingers are down.
@MainActor
enum PreviewOverlay {
    private static let panel: NSPanel = {
        let panel = makePanel()
        // A light accent tint keeps what's underneath readable, so the user sees what will be covered.
        let box = NSView()
        box.wantsLayer = true
        box.layer?.cornerRadius = 12
        box.layer?.borderWidth = 2
        box.layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.8).cgColor
        box.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.2).cgColor
        panel.contentView = box
        return panel
    }()

    /// Hold-to-grid's cells, under the preview.
    private static let gridPanel: NSPanel = {
        let panel = makePanel()
        panel.level = .init(NSWindow.Level.floating.rawValue - 1)
        panel.contentView = GridView()
        return panel
    }()

    private static func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.animationBehavior = .none
        return panel
    }

    static var isEnabled: Bool { UserDefaults.standard.object(forKey: "preview") as? Bool ?? true }

    /// Accessibility coordinates (top-left origin on the primary screen) to Cocoa's (bottom-left).
    private static func cocoa(_ frame: CGRect) -> CGRect {
        let top = NSScreen.screens.first?.frame.maxY ?? 0
        return CGRect(x: frame.minX, y: top - frame.maxY, width: frame.width, height: frame.height)
    }

    /// `frame` in Accessibility coordinates. The grid shows it even with previews turned off, as it's all it has.
    static func show(_ frame: CGRect, always: Bool = false) {
        guard isEnabled || always else { return }
        let cocoa = cocoa(frame)
        if panel.isVisible {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.12
                panel.animator().setFrame(cocoa, display: true)
            }
        } else {
            panel.setFrame(cocoa, display: true)
            panel.orderFrontRegardless()
        }
    }

    /// Outlines `cells` (Accessibility coordinates) over a slightly dimmed screen.
    static func showGrid(_ cells: [CGRect]) {
        let bounds = cocoa(cells.reduce(CGRect.null) { $0.union($1) }).insetBy(dx: -8, dy: -8)
        let view = gridPanel.contentView as! GridView
        view.cells = cells.map { cocoa($0).offsetBy(dx: -bounds.minX, dy: -bounds.minY) }
        gridPanel.setFrame(bounds, display: true)
        gridPanel.orderFrontRegardless()
    }

    static func hide() {
        if panel.isVisible { panel.orderOut(nil) }
        if gridPanel.isVisible { gridPanel.orderOut(nil) }
    }
}

/// Built from layers rather than `draw(_:)`: drawing a screen-sized view on the CPU took over a second the first
/// time, long enough for macOS to turn off the event tap.
private final class GridView: NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.12).cgColor
        layer?.cornerRadius = 14
    }

    required init?(coder: NSCoder) { nil }

    var cells: [CGRect] = [] {
        didSet {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            layer?.sublayers = cells.map { cell in
                let shape = CAShapeLayer()
                shape.path = CGPath(roundedRect: cell.insetBy(dx: 2, dy: 2), cornerWidth: 10, cornerHeight: 10, transform: nil)
                shape.fillColor = NSColor.white.withAlphaComponent(0.08).cgColor
                shape.strokeColor = NSColor.white.withAlphaComponent(0.7).cgColor
                shape.lineWidth = 1.5
                shape.lineDashPattern = [6, 4]
                return shape
            }
            CATransaction.commit()
        }
    }
}
