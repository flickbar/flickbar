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
    /// The Dock tile of a minimized window the gesture started on.
    private var minimizedTile: AXUIElement?
    private var tracking: Bool { target != nil || dockApp != nil || minimizedTile != nil }
    private var swallowMomentum = false
    private var command = false
    private var escaped = false
    /// Hold-to-grid: set once the fingers rest on a title bar before a swipe registers.
    private var grid: GridCursor?
    private var gridScreen: CGRect?
    private var holdTimer: Timer?
    private var origin = CGPoint.zero
    private static let holdDelay: TimeInterval = 0.4

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
            logger.notice("event tap was disabled (\(type == .tapDisabledByTimeout ? "too slow" : "by input", privacy: .public)); re-enabling")
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
        let dx = sign * e.scrollingDeltaX, dy = sign * e.scrollingDeltaY
        if grid != nil {
            if grid!.move(dx: dx, dy: dy) { showGridCell() }
        } else {
            if recognizer.addScroll(dx: dx, dy: dy) != nil { strokeRecognized() }
            armHold()
        }
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
        grid = nil
        holdTimer?.invalidate()
        origin = point
        let hit = AXWindow.element(at: point)
        target = hit.flatMap { Self.window(of: $0, at: point, flags: flags) }
        dockApp = target == nil ? hit.flatMap(AppControl.app(ofDockItem:)) : nil
        minimizedTile = target == nil && dockApp == nil ? hit.flatMap(AppControl.minimizedWindowTile) : nil
        logger.debug("gesture began at \(point.debugDescription, privacy: .public), on window: \(self.target != nil, privacy: .public), on Dock: \(self.dockApp?.bundleIdentifier ?? "no", privacy: .public), on minimized window: \(self.minimizedTile != nil, privacy: .public)")
    }

    /// A tick and a preview of where the window will land tell the user the gesture so far maps to an action,
    /// before they lift their fingers.
    private func strokeRecognized() {
        guard !escaped, let action = currentAction() else { return PreviewOverlay.hide() }
        tick()
        if let target, let frame = WindowActions.landingFrame(of: action, on: target) { PreviewOverlay.show(frame) } else { PreviewOverlay.hide() }
    }

    private func tick() {
        if UserDefaults.standard.object(forKey: "haptics") as? Bool ?? true {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }
    }

    /// Trackpads send nothing while the fingers rest, so a timer restarted by every movement spots the hold.
    private func armHold() {
        holdTimer?.invalidate()
        guard target != nil, recognizer.strokes.isEmpty, !command, !escaped else { return }
        holdTimer = Timer.scheduledTimer(withTimeInterval: Self.holdDelay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.enterGrid() }
        }
    }

    private func enterGrid() {
        guard let target, recognizer.strokes.isEmpty, !escaped, let screen = target.screen else { return }
        grid = GridCursor(x: origin.x, in: screen)
        gridScreen = screen
        PreviewOverlay.showGrid(GridCursor.outline(in: screen, gap: WindowActions.gap))
        showGridCell()
    }

    private func showGridCell() {
        guard let grid, let gridScreen, !escaped else { return }
        tick()
        PreviewOverlay.show(grid.frame(in: gridScreen, gap: WindowActions.gap), always: true)
    }

    /// The action the strokes so far map to, with the user's choices from Settings.
    private func currentAction() -> WindowAction? {
        guard minimizedTile != nil else {
            return ActionMap.action(for: recognizer.strokes, command: command, onDock: dockApp != nil, overrides: Self.gestureMap)
        }
        // On a minimized window, swipe up just brings it back (restore-or-minimize does exactly that to a minimized
        // window); other gestures bring it back and then do what they do on a title bar. Minimizing again does nothing.
        if recognizer.strokes == [.up] { return .restoreOrMinimize }
        let action = ActionMap.action(for: recognizer.strokes, overrides: Self.gestureMap)
        return action == .minimize || action == .restoreOrMinimize ? nil : action
    }

    private func finish(cancelled: Bool) {
        PreviewOverlay.hide()
        holdTimer?.invalidate()
        if let grid, let gridScreen, let target {
            if !cancelled, !escaped { WindowActions.place(target, at: grid.frame(in: gridScreen, gap: WindowActions.gap)) }
        } else if !cancelled, !escaped, let action = currentAction() {
            if let target {
                WindowActions.run(action, on: target)
            } else if let dockApp {
                AppControl.perform(action, on: dockApp)
            } else if let minimizedTile {
                // Finding the window asks every app for its windows; don't hold up the event tap while it does.
                DispatchQueue.main.async { AppControl.restore(minimizedTile, then: action == .restoreOrMinimize ? nil : action) }
            }
        }
        swallowMomentum = true
        target = nil
        dockApp = nil
        minimizedTile = nil
        grid = nil
        recognizer.reset()
    }
}
