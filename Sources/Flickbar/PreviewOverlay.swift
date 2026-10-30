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

    /// Fast at the start and settling gently, like a spring without the overshoot that would misplace an edge.
    private static let easeOut = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.25, 1)
    private static var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
    /// Per panel, bumped when it's presented or hidden, so a fade-out that finishes after the panel came back leaves it up.
    private static var generations: [ObjectIdentifier: Int] = [:]

    private static func animate(_ duration: TimeInterval, _ changes: @escaping () -> Void, done: (@Sendable () -> Void)? = nil) {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = duration
            ctx.timingFunction = easeOut
            changes()
        }, completionHandler: done)
    }

    /// Moves `panel` to `frame`: gliding there if it's already up, otherwise growing and fading in.
    private static func present(_ panel: NSPanel, at frame: CGRect, glide: Bool) {
        generations[ObjectIdentifier(panel), default: 0] += 1
        if panel.isVisible {
            animate(0.2) {
                if glide && !reduceMotion { panel.animator().setFrame(frame, display: true) } else { panel.setFrame(frame, display: true) }
                panel.animator().alphaValue = 1
            }
        } else {
            let inset = glide && !reduceMotion ? min(frame.width, frame.height) * 0.04 : 0
            panel.setFrame(frame.insetBy(dx: inset, dy: inset), display: true)
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            animate(reduceMotion ? 0.1 : 0.18) {
                if inset > 0 { panel.animator().setFrame(frame, display: true) }
                panel.animator().alphaValue = 1
            }
        }
    }

    /// `frame` in Accessibility coordinates. The grid shows it even with previews turned off, as it's all it has.
    static func show(_ frame: CGRect, always: Bool = false) {
        guard isEnabled || always else { return }
        present(panel, at: cocoa(frame), glide: true)
    }

    /// Outlines `cells` (Accessibility coordinates) over a slightly dimmed screen.
    static func showGrid(_ cells: [CGRect]) {
        let bounds = cocoa(cells.reduce(CGRect.null) { $0.union($1) }).insetBy(dx: -8, dy: -8)
        let view = gridPanel.contentView as! GridView
        view.cells = cells.map { cocoa($0).offsetBy(dx: -bounds.minX, dy: -bounds.minY) }
        present(gridPanel, at: bounds, glide: false)
    }

    static func hide() {
        for panel in [panel, gridPanel] where panel.isVisible {
            let id = ObjectIdentifier(panel)
            generations[id, default: 0] += 1
            let fading = generations[id]
            animate(reduceMotion ? 0.1 : 0.15) {
                panel.animator().alphaValue = 0
            } done: {
                MainActor.assumeIsolated { if generations[id] == fading { panel.orderOut(nil) } }
            }
        }
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
