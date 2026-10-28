import AppKit

/// A translucent rounded rectangle showing where the window will land, shown while the fingers are down.
@MainActor
enum PreviewOverlay {
    private static let panel: NSPanel = {
        let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.animationBehavior = .none

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

    static var isEnabled: Bool { UserDefaults.standard.object(forKey: "preview") as? Bool ?? true }

    /// `frame` in Accessibility coordinates (top-left origin on the primary screen).
    static func show(_ frame: CGRect) {
        guard isEnabled, let primary = NSScreen.screens.first else { return }
        let cocoa = CGRect(x: frame.minX, y: primary.frame.maxY - frame.maxY, width: frame.width, height: frame.height)
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

    static func hide() {
        guard panel.isVisible else { return }
        panel.orderOut(nil)
    }
}
