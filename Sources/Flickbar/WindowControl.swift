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

    /// The window under `point`, if any; with `titleBarOnly`, only when the point is on its title bar.
    static func at(_ point: CGPoint, titleBarOnly: Bool) -> AXWindow? {
        var hit: AXUIElement?
        guard AXUIElementCopyElementAtPosition(systemWide, Float(point.x), Float(point.y), &hit) == .success,
              let hit else { return nil }
        let window: AXUIElement? = hit.string(kAXRoleAttribute) == kAXWindowRole ? hit : hit.element(kAXWindowAttribute)
        guard let window, window.string(kAXSubroleAttribute) == kAXStandardWindowSubrole else { return nil }

        var pid: pid_t = 0
        guard AXUIElementGetPid(window, &pid) == .success, pid != getpid(),
              !GestureTap.excludedApps.contains(NSRunningApplication(processIdentifier: pid)?.bundleIdentifier ?? ""),
              let frame = window.frame else { return nil }
        let candidate = AXWindow(element: window, app: AXUIElementCreateApplication(pid))
        guard titleBarOnly else { return candidate }
        let height = candidate.titlebarHeight(windowTop: frame.minY)
        return point.y - frame.minY <= height ? candidate : nil
    }

    /// The frontmost app's focused window, for keyboard shortcuts.
    static func focused() -> AXWindow? {
        guard let app = NSWorkspace.shared.frontmostApplication, app.processIdentifier != getpid() else { return nil }
        let element = AXUIElementCreateApplication(app.processIdentifier)
        guard let window = element.element(kAXFocusedWindowAttribute),
              window.string(kAXSubroleAttribute) == kAXStandardWindowSubrole else { return nil }
        return AXWindow(element: window, app: element)
    }

    /// The traffic-light buttons sit vertically centred in the title bar (also in tall unified toolbars),
    /// so mirror the close button's top padding below it.
    private func titlebarHeight(windowTop: CGFloat) -> CGFloat {
        guard let close = element.element(kAXCloseButtonAttribute)?.frame else { return Self.fallbackTitlebarHeight }
        return max(Self.fallbackTitlebarHeight, close.maxY + (close.minY - windowTop) - windowTop)
    }

    var frame: CGRect? { element.frame }

    /// Where `action` would put the window, for actions that move it. Shared by the preview and `perform`.
    func targetFrame(for action: WindowAction, gap: CGFloat = 0) -> CGRect? {
        guard let current = frame, let source = Self.visibleFrame(containing: current) else { return nil }
        switch action {
        case .snap(let target):
            let target = SnapGeometry.cycled(target, in: source, current: current, gap: gap)
            return SnapGeometry.frame(for: target, in: source, current: current, gap: gap)
        case .moveToDisplay(let direction):
            guard let destination = SnapGeometry.neighbor(of: source, in: Self.visibleFrames(), toward: direction) else { return nil }
            return SnapGeometry.relocate(current, from: source, to: destination)
        default:
            return nil
        }
    }

    func perform(_ action: WindowAction, gap: CGFloat = 0) {
        switch action {
        case .snap, .moveToDisplay:
            guard let target = targetFrame(for: action, gap: gap) else { return }
            setFrame(target)
            // Apps with a minimum or maximum size keep their own; line it up with the target instead.
            if let actual = frame, !actual.isClose(to: target, tolerance: 2), let visible = Self.visibleFrame(containing: target) {
                setFrame(SnapGeometry.anchored(actual.size, to: target, in: visible))
            }
        case .minimize:
            AXUIElementSetAttributeValue(element, kAXMinimizedAttribute as CFString, kCFBooleanTrue)
        case .close:
            if let button = element.element(kAXCloseButtonAttribute) {
                AXUIElementPerformAction(button, kAXPressAction as CFString)
            }
        case .toggleFullscreen:
            let isFull = element.bool("AXFullScreen") ?? false
            AXUIElementSetAttributeValue(element, "AXFullScreen" as CFString, (!isFull) as CFBoolean)
        case .nextWindow:
            // Windows are listed front to back, so raising the last one cycles through all of them.
            let windows = (app.value(kAXWindowsAttribute) as? [AXUIElement] ?? []).filter {
                $0.string(kAXSubroleAttribute) == kAXStandardWindowSubrole && $0.bool(kAXMinimizedAttribute) != true
            }
            guard let back = windows.last, windows.count > 1 else { return }
            AXUIElementPerformAction(back, kAXRaiseAction as CFString)
            runningApplication?.activate()
        case .hideApp:
            runningApplication?.hide()
        case .quitApp:
            runningApplication?.terminate()
        }
    }

    private var runningApplication: NSRunningApplication? {
        var pid: pid_t = 0
        return AXUIElementGetPid(app, &pid) == .success ? NSRunningApplication(processIdentifier: pid) : nil
    }

    func setFrame(_ rect: CGRect) {
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
