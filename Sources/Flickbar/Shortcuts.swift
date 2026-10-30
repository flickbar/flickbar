import AppKit
import FlickbarCore
import KeyboardShortcuts

/// Global keyboard shortcuts, one per window action; none are set until the user records them.
@MainActor
enum Shortcuts {
    static let displayMoves = [Stroke.left, .right, .up, .down].map(WindowAction.moveToDisplay)
    static let actions = WindowAction.assignable + displayMoves

    static func name(_ action: WindowAction) -> KeyboardShortcuts.Name { KeyboardShortcuts.Name(action.id) }

    /// Before 0.9 the `minimize` shortcut restored or minimized; move it to the action that still does, once.
    static func migratePreferences() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: "migratedRestoreShortcut") else { return }
        defaults.set(true, forKey: "migratedRestoreShortcut")
        let old = name(.minimize), new = name(.restoreOrMinimize)
        guard let shortcut = KeyboardShortcuts.getShortcut(for: old), KeyboardShortcuts.getShortcut(for: new) == nil else { return }
        KeyboardShortcuts.setShortcut(shortcut, for: new)
        KeyboardShortcuts.setShortcut(nil, for: old)
    }

    static func install() {
        for action in actions {
            KeyboardShortcuts.onKeyDown(for: name(action)) {
                logger.debug("shortcut \(action.id, privacy: .public), focused window: \(AXWindow.focused() != nil, privacy: .public)")
                guard let window = AXWindow.focused() else { return NSSound.beep() }
                WindowActions.run(action, on: window)
            }
        }
    }
}
