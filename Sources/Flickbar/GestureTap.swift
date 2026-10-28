import AppKit
import FlickbarCore

/// Listens to trackpad scroll and pinch events system-wide. Gestures that start on a window's
/// title bar are consumed and turned into window actions; everything else passes through untouched.
@MainActor
final class GestureTap {
    private var tap: CFMachPort?
    private var recognizer = GestureRecognizer()
    private var target: AXWindow?
    private var swallowMomentum = false
    private var command = false
    private var escaped = false
    // shortcut: entries for closed windows are never pruned, a few bytes each; prune if it ever matters.
    private var restoreMemory = RestoreMemory<AXUIElement>()

    /// Bundle IDs of apps where title-bar gestures are turned off.
    static var excludedApps: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: "excludedApps") ?? []) }
        set { UserDefaults.standard.set(newValue.sorted(), forKey: "excludedApps") }
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
            guard target != nil, event.getIntegerValueField(.keyboardEventKeycode) == escape else { return false }
            // Keep consuming the rest of the gesture so it doesn't leak into the app; it just won't fire.
            escaped = true
            return true
        }
        guard let ns = NSEvent(cgEvent: event) else { return false }
        return switch ns.type {
        case .scrollWheel: handleScroll(ns, at: event.location)
        case .magnify: handlePinch(ns, at: event.location)
        case .smartMagnify: handleDoubleTap(at: event.location)
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
        guard target != nil else { return false }

        // Convert content-scroll deltas to finger movement, regardless of the natural-scrolling setting.
        let sign: CGFloat = e.isDirectionInvertedFromDevice ? 1 : -1
        if recognizer.addScroll(dx: sign * e.scrollingDeltaX, dy: sign * e.scrollingDeltaY) != nil { strokeRecognized() }
        if e.phase.contains(.ended) || e.phase.contains(.cancelled) { finish(cancelled: e.phase.contains(.cancelled)) }
        return true
    }

    private func handlePinch(_ e: NSEvent, at point: CGPoint) -> Bool {
        if e.phase.contains(.began) { begin(at: point, flags: e.modifierFlags) }
        guard target != nil else { return false }
        if recognizer.addMagnification(e.magnification) != nil { strokeRecognized() }
        if e.phase.contains(.ended) || e.phase.contains(.cancelled) { finish(cancelled: e.phase.contains(.cancelled)) }
        return true
    }

    private func handleDoubleTap(at point: CGPoint) -> Bool {
        guard let window = AXWindow.titlebar(at: point) else { return false }
        run(.snap(.center), on: window)
        return true
    }

    private func begin(at point: CGPoint, flags: NSEvent.ModifierFlags) {
        recognizer.reset()
        swallowMomentum = false
        command = flags.contains(.command)
        escaped = false
        target = AXWindow.titlebar(at: point)
        logger.debug("gesture began at \(point.debugDescription, privacy: .public), on title bar: \(self.target != nil, privacy: .public)")
    }

    /// A tick tells the user the gesture so far maps to an action, before they lift their fingers.
    private func strokeRecognized() {
        guard !escaped, ActionMap.action(for: recognizer.strokes, command: command) != nil else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }

    /// Swipe down on a window Flickbar placed restores it; otherwise the action runs and moves are remembered.
    private func run(_ action: WindowAction, on window: AXWindow) {
        if action == .minimize, let current = window.frame,
           let original = restoreMemory.takeOriginal(window.element, current: current) {
            window.setFrame(original)
            return
        }
        let before = window.frame
        window.perform(action, gap: CGFloat(UserDefaults.standard.integer(forKey: "gap")))
        switch action {
        case .snap, .moveToDisplay:
            if let before, let after = window.frame { restoreMemory.record(window.element, from: before, to: after) }
        default: break
        }
    }

    private func finish(cancelled: Bool) {
        if !cancelled, !escaped, let target, let action = ActionMap.action(for: recognizer.strokes, command: command) {
            run(action, on: target)
        }
        swallowMomentum = true
        target = nil
        recognizer.reset()
    }
}
