import AppKit
import ApplicationServices
import FlickbarCore

/// A window found through the Accessibility API. Coordinates are global, top-left origin.
@MainActor
struct AXWindow {
    let element: AXUIElement
    let app: AXUIElement

    private static let systemWide = AXUIElementCreateSystemWide()
    private static let fallbackTitlebarHeight: CGFloat = 28

    /// The window whose title bar is under `point`, if any.
    static func titlebar(at point: CGPoint) -> AXWindow? {
        var hit: AXUIElement?
        guard AXUIElementCopyElementAtPosition(systemWide, Float(point.x), Float(point.y), &hit) == .success,
              let hit else { return nil }
        let window: AXUIElement? = hit.string(kAXRoleAttribute) == kAXWindowRole ? hit : hit.element(kAXWindowAttribute)
        guard let window, window.string(kAXSubroleAttribute) == kAXStandardWindowSubrole else { return nil }

        var pid: pid_t = 0
        guard AXUIElementGetPid(window, &pid) == .success, pid != getpid(),
              let frame = window.frame else { return nil }
        let candidate = AXWindow(element: window, app: AXUIElementCreateApplication(pid))
        let height = candidate.titlebarHeight(windowTop: frame.minY)
        return point.y - frame.minY <= height ? candidate : nil
    }

    /// The traffic-light buttons sit vertically centred in the title bar (also in tall unified toolbars),
    /// so mirror the close button's top padding below it.
    private func titlebarHeight(windowTop: CGFloat) -> CGFloat {
        guard let close = element.element(kAXCloseButtonAttribute)?.frame else { return Self.fallbackTitlebarHeight }
        return max(Self.fallbackTitlebarHeight, close.maxY + (close.minY - windowTop) - windowTop)
    }

    var frame: CGRect? { element.frame }

    func perform(_ action: WindowAction, gap: CGFloat = 0) {
        switch action {
        case .snap(let target):
            guard let current = frame, let visible = Self.visibleFrame(containing: current) else { return }
            setFrame(SnapGeometry.frame(for: target, in: visible, current: current, gap: gap))
        case .moveToDisplay(let direction):
            let screens = Self.visibleFrames()
            guard let current = frame, let source = Self.visibleFrame(containing: current),
                  let destination = SnapGeometry.neighbor(of: source, in: screens, toward: direction) else { return }
            setFrame(SnapGeometry.relocate(current, from: source, to: destination))
        case .minimize:
            AXUIElementSetAttributeValue(element, kAXMinimizedAttribute as CFString, kCFBooleanTrue)
        case .close:
            if let button = element.element(kAXCloseButtonAttribute) {
                AXUIElementPerformAction(button, kAXPressAction as CFString)
            }
        case .toggleFullscreen:
            let isFull = element.bool("AXFullScreen") ?? false
            AXUIElementSetAttributeValue(element, "AXFullScreen" as CFString, (!isFull) as CFBoolean)
        }
    }

    private func setFrame(_ rect: CGRect) {
        // Apps with enhanced UI on (set by assistive tools) animate and ignore frame changes.
        let enhanced = app.bool("AXEnhancedUserInterface") ?? false
        if enhanced { AXUIElementSetAttributeValue(app, "AXEnhancedUserInterface" as CFString, kCFBooleanFalse) }
        defer { if enhanced { AXUIElementSetAttributeValue(app, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue) } }

        var size = rect.size, origin = rect.origin
        let axSize = AXValueCreate(.cgSize, &size)!, axOrigin = AXValueCreate(.cgPoint, &origin)!
        // Size first so the move isn't clamped by the old screen, then again in case the move clamped it.
        AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, axSize)
        AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, axOrigin)
        AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, axSize)
    }

    /// Visible frames (minus menu bar and Dock) of all screens, in AX coordinates.
    private static func visibleFrames() -> [CGRect] {
        guard let primary = NSScreen.screens.first else { return [] }
        return NSScreen.screens.map { s in
            let r = s.visibleFrame
            return CGRect(x: r.minX, y: primary.frame.maxY - r.maxY, width: r.width, height: r.height)
        }
    }

    /// Visible frame of the screen holding most of `rect`.
    private static func visibleFrame(containing rect: CGRect) -> CGRect? {
        visibleFrames().max { $0.intersection(rect).area < $1.intersection(rect).area }
    }
}

private extension CGRect {
    var area: CGFloat { isNull ? 0 : width * height }
}

private extension AXUIElement {
    func value(_ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(self, attribute as CFString, &value) == .success ? value : nil
    }

    func string(_ attribute: String) -> String? { value(attribute) as? String }
    func bool(_ attribute: String) -> Bool? { (value(attribute) as? NSNumber)?.boolValue }

    func element(_ attribute: String) -> AXUIElement? {
        guard let v = value(attribute), CFGetTypeID(v) == AXUIElementGetTypeID() else { return nil }
        return (v as! AXUIElement)
    }

    var frame: CGRect? {
        guard let p = value(kAXPositionAttribute), let s = value(kAXSizeAttribute) else { return nil }
        var origin = CGPoint.zero, size = CGSize.zero
        guard AXValueGetValue(p as! AXValue, .cgPoint, &origin),
              AXValueGetValue(s as! AXValue, .cgSize, &size) else { return nil }
        return CGRect(origin: origin, size: size)
    }
}
