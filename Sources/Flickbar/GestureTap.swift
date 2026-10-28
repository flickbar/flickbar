import AppKit
import FlickbarCore

/// Listens to trackpad scroll and pinch events system-wide. Gestures that start on a window's
/// title bar are consumed and turned into window actions; everything else passes through untouched.
@MainActor
final class GestureTap {
    private var tap: CFMachPort?
    private var recognizer = GestureRecognizer()
    private var target: AXWindow?
    /// The app whose Dock icon the gesture started on, when it didn't start on a window.
    private var dockApp: NSRunningApplication?
    private var tracking: Bool { target != nil || dockApp != nil }
    private var swallowMomentum = false
    private var command = false
    private var escaped = false

    /// Bundle IDs of apps where title-bar gestures are turned off.
    static var excludedApps: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: "excludedApps") ?? []) }
        set { UserDefaults.standard.set(newValue.sorted(), forKey: "excludedApps") }
    }

    /// The user's gesture → action choices (see `ActionMap`); gestures not in it do their default.
    static var gestureMap: [String: String] {
        get { UserDefaults.standard.dictionary(forKey: "gestureMap") as? [String: String] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: "gestureMap") }
    }

    /// Version 0.2 had on/off switches per gesture group; turn those into `gestureMap` entries once.
    static func migratePreferences() {
        guard let old = UserDefaults.standard.stringArray(forKey: "disabledGestures") else { return }
        gestureMap.merge(ActionMap.migrate(disabled: old)) { current, _ in current }
        UserDefaults.standard.removeObject(forKey: "disabledGestures")
    }

    /// Holding this key makes gestures work anywhere in a window, not just on its title bar. Nil when off.
    static var anywhereModifier: NSEvent.ModifierFlags? {
        switch UserDefaults.standard.string(forKey: "anywhereModifier") ?? "option" {
        case "option": .option
        case "control": .control
        default: nil
        }
    }

    var isEnabled = false {
        didSet {
            if isEnabled, tap == nil { install() }
            if let tap { CGEvent.tapEnable(tap: tap, enable: isEnabled) }
        }
    }

    private func install() {
        // 10 keyDown (Esc cancels), 22 scrollWheel, 29 gesture, 30 magnify, 32 smartMagnify (two-finger double tap).
        let mask: CGEventMask = (1 << 10) | (1 << 22) | (1 << 29) | (1 << 30) | (1 << 32)
        let callback: CGEventTapCallBack = { _, type, event, info in
            let me = Unmanaged<GestureTap>.fromOpaque(info!).takeUnretainedValue()
            let consumed = MainActor.assumeIsolated { me.handle(type, event) }
            return consumed ? nil : Unmanaged.passUnretained(event)
        }
        tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                eventsOfInterest: mask, callback: callback,
                                userInfo: Unmanaged.passUnretained(self).toOpaque())
        guard let tap else { return logger.error("event tap creation failed (not trusted for Accessibility?)") }
        logger.notice("event tap installed")
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
    }

    /// Returns true when the event was used for a gesture and must not reach the app below.
    private func handle(_ type: CGEventType, _ event: CGEvent) -> Bool {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap, isEnabled { CGEvent.tapEnable(tap: tap, enable: true) }
            return false
        }
        if type == .keyDown {
            let escape: Int64 = 53
            guard tracking, event.getIntegerValueField(.keyboardEventKeycode) == escape else { return false }
            // Keep consuming the rest of the gesture so it doesn't leak into the app; it just won't fire.
            escaped = true
            PreviewOverlay.hide()
            return true
        }
        guard let ns = NSEvent(cgEvent: event) else { return false }
        return switch ns.type {
        case .scrollWheel: handleScroll(ns, at: event.location)
        case .magnify: handlePinch(ns, at: event.location)
        case .smartMagnify: handleDoubleTap(at: event.location, flags: ns.modifierFlags)
        default: false
        }
    }

    private func handleScroll(_ e: NSEvent, at point: CGPoint) -> Bool {
        // Mouse wheels report no phase; only trackpad / Magic Mouse touch scrolling does.
        if !e.momentumPhase.isEmpty {
            let swallow = swallowMomentum
            if e.momentumPhase.contains(.ended) { swallowMomentum = false }
            return swallow
        }
        if e.phase.contains(.began) { begin(at: point, flags: e.modifierFlags) }
        guard tracking else { return false }

        // Convert content-scroll deltas to finger movement, regardless of the natural-scrolling setting.
        let sign: CGFloat = e.isDirectionInvertedFromDevice ? 1 : -1
        if recognizer.addScroll(dx: sign * e.scrollingDeltaX, dy: sign * e.scrollingDeltaY) != nil { strokeRecognized() }
        if e.phase.contains(.ended) || e.phase.contains(.cancelled) { finish(cancelled: e.phase.contains(.cancelled)) }
        return true
    }

    private func handlePinch(_ e: NSEvent, at point: CGPoint) -> Bool {
        if e.phase.contains(.began) { begin(at: point, flags: e.modifierFlags) }
        guard tracking else { return false }
        if recognizer.addMagnification(e.magnification) != nil { strokeRecognized() }
        if e.phase.contains(.ended) || e.phase.contains(.cancelled) { finish(cancelled: e.phase.contains(.cancelled)) }
        return true
    }

    private func handleDoubleTap(at point: CGPoint, flags: NSEvent.ModifierFlags) -> Bool {
        guard let action = ActionMap.action(for: .doubleTap, overrides: Self.gestureMap),
              let window = Self.window(at: point, flags: flags) else { return false }
        WindowActions.run(action, on: window)
        return true
    }

    private static func window(at point: CGPoint, flags: NSEvent.ModifierFlags) -> AXWindow? {
        AXWindow.element(at: point).flatMap { window(of: $0, at: point, flags: flags) }
    }

    private static func window(of hit: AXUIElement, at point: CGPoint, flags: NSEvent.ModifierFlags) -> AXWindow? {
        let anywhere = anywhereModifier.map(flags.contains) ?? false
        return AXWindow.of(hit, at: point, titleBarOnly: !anywhere)
    }

    private func begin(at point: CGPoint, flags: NSEvent.ModifierFlags) {
        recognizer.reset()
        swallowMomentum = false
        command = flags.contains(.command)
        escaped = false
        let hit = AXWindow.element(at: point)
        target = hit.flatMap { Self.window(of: $0, at: point, flags: flags) }
        dockApp = target == nil ? hit.flatMap(AppControl.app(ofDockItem:)) : nil
        logger.debug("gesture began at \(point.debugDescription, privacy: .public), on window: \(self.target != nil, privacy: .public), on Dock: \(self.dockApp?.bundleIdentifier ?? "no", privacy: .public)")
    }

    /// A tick and a preview of where the window will land tell the user the gesture so far maps to an action,
    /// before they lift their fingers.
    private func strokeRecognized() {
        guard !escaped, let action = currentAction() else { return PreviewOverlay.hide() }
        if UserDefaults.standard.object(forKey: "haptics") as? Bool ?? true {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }
        if let target, let frame = WindowActions.landingFrame(of: action, on: target) { PreviewOverlay.show(frame) } else { PreviewOverlay.hide() }
    }

    /// The action the strokes so far map to, with the user's choices from Settings.
    private func currentAction() -> WindowAction? {
        ActionMap.action(for: recognizer.strokes, command: command, onDock: dockApp != nil, overrides: Self.gestureMap)
    }

    private func finish(cancelled: Bool) {
        PreviewOverlay.hide()
        if !cancelled, !escaped, let action = currentAction() {
            if let target { WindowActions.run(action, on: target) } else if let dockApp { AppControl.perform(action, on: dockApp) }
        }
        swallowMomentum = true
        target = nil
        dockApp = nil
        recognizer.reset()
    }
}
