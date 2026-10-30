import AppKit
import FlickbarCore

/// Runs window actions for gestures and keyboard shortcuts alike, so both share restore memory.
@MainActor
enum WindowActions {
    // shortcut: entries for closed windows are never pruned, a few bytes each; prune if it ever matters.
    private static var restoreMemory = RestoreMemory<AXUIElement>()

    static var gap: CGFloat { CGFloat(UserDefaults.standard.integer(forKey: "gap")) }

    /// Where `run` would put the window; nil for actions that don't move it.
    static func landingFrame(of action: WindowAction, on window: AXWindow) -> CGRect? {
        if action == .restoreOrMinimize {
            guard let current = window.frame else { return nil }
            return restoreMemory.original(window.element, current: current)
        }
        return window.targetFrame(for: action, gap: gap)
    }

    /// Moves the window to a frame chosen on the grid, remembering where it was.
    static func place(_ window: AXWindow, at frame: CGRect) {
        let before = window.frame
        window.place(frame)
        if let before, let after = window.frame { restoreMemory.record(window.element, from: before, to: after) }
        Tutorial.report(TutorialStep.gridID, on: window)
    }

    /// Restore-or-minimize on a window Flickbar placed restores it; otherwise the action runs and moves are remembered.
    static func run(_ action: WindowAction, on window: AXWindow) {
        Tutorial.report(action.id, on: window)
        if action == .restoreOrMinimize, let current = window.frame,
           let original = restoreMemory.takeOriginal(window.element, current: current) {
            window.setFrame(original)
            return
        }
        let before = window.frame
        window.perform(action, gap: gap)
        switch action {
        case .snap, .moveToDisplay:
            if let before, let after = window.frame { restoreMemory.record(window.element, from: before, to: after) }
        default: break
        }
    }
}
