import AppKit
import Carbon.HIToolbox
import FlickbarCore
import KeyboardShortcuts
import SwiftUI

/// Records one action's shortcut. Own recorder instead of `KeyboardShortcuts.Recorder`, whose clear button and Escape
/// didn't delete, and which rejected keys with a beep or an alert that could fail to show. Storage and the global
/// hotkey still go through KeyboardShortcuts.
struct ShortcutRecorder: View {
    let action: WindowAction
    @State private var shortcut: KeyboardShortcuts.Shortcut?
    @State private var isRecording = false
    @State private var rejection: String?
    @State private var monitor: Any?

    init(action: WindowAction) {
        self.action = action
        _shortcut = State(initialValue: KeyboardShortcuts.getShortcut(for: Shortcuts.name(action)))
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack(spacing: 6) {
                Button(action: start) {
                    Text(label)
                        .opacity(isRecording && shortcut != nil ? 0.35 : 1) // the old shortcut fades while a new one is awaited
                        .foregroundStyle(shortcut == nil ? .secondary : .primary)
                        .frame(minWidth: 110)
                }
                .overlay { if isRecording { RoundedRectangle(cornerRadius: 6).stroke(Color.accentColor, lineWidth: 2) } }
                if shortcut != nil {
                    Button(action: clear) { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear Shortcut")
                }
            }
            if let rejection {
                Text(rejection).font(.caption).foregroundStyle(.red).multilineTextAlignment(.trailing)
            }
        }
        .onDisappear(perform: stop)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in stop() }
    }

    private var label: String {
        if let shortcut { return "\(shortcut)" }
        return isRecording ? String(localized: "Press Shortcut") : String(localized: "Record Shortcut")
    }

    private func start() {
        stop()
        rejection = nil
        isRecording = true
        KeyboardShortcuts.isEnabled = false // a held global shortcut would otherwise swallow the key before we see it
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown]) { event in
            // A click anywhere, this field included, cancels; the field's own click then starts a fresh recording.
            guard event.type == .keyDown else { stop(); return event }
            handle(event)
            return nil
        }
    }

    private func stop() {
        guard isRecording else { return }
        isRecording = false
        KeyboardShortcuts.isEnabled = true
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    private func clear() {
        KeyboardShortcuts.setShortcut(nil, for: Shortcuts.name(action))
        shortcut = nil
        rejection = nil
        stop()
    }

    private func handle(_ event: NSEvent) {
        let modifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])
        let isFunctionKey = Self.functionKeys.contains(Int(event.keyCode))
        if modifiers.isEmpty, [kVK_Escape, kVK_Delete, kVK_ForwardDelete].contains(Int(event.keyCode)) { return clear() }
        guard let candidate = KeyboardShortcuts.Shortcut(event: event) else { return reject(String(localized: "That key can't be used.")) }
        if let reason = Self.problem(with: candidate, modifiers: modifiers, isFunctionKey: isFunctionKey, for: action) { return reject(reason) }
        KeyboardShortcuts.setShortcut(candidate, for: Shortcuts.name(action))
        shortcut = candidate
        stop()
    }

    private func reject(_ reason: String) {
        rejection = reason
        stop()
    }

    private static let functionKeys: Set<Int> = [kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8, kVK_F9, kVK_F10,
                                                  kVK_F11, kVK_F12, kVK_F13, kVK_F14, kVK_F15, kVK_F16, kVK_F17, kVK_F18, kVK_F19, kVK_F20]

    /// Why `shortcut` can't be used for `action`, or nil when it can.
    private static func problem(with shortcut: KeyboardShortcuts.Shortcut, modifiers: NSEvent.ModifierFlags, isFunctionKey: Bool, for action: WindowAction) -> String? {
        if modifiers.isDisjoint(with: [.command, .control, .option]) && !isFunctionKey {
            return String(localized: "Hold ⌘, ⌃ or ⌥ together with the key.")
        }
        if let other = Shortcuts.actions.first(where: { $0.id != action.id && KeyboardShortcuts.getShortcut(for: Shortcuts.name($0)) == shortcut }) {
            return String(format: String(localized: "Already used for %@."), ActionNames.title(other))
        }
        if shortcut.isTakenBySystem {
            return String(format: String(localized: "macOS already uses %@. Change it in System Settings › Keyboard › Keyboard Shortcuts."), "\(shortcut)")
        }
        // Shortcuts are paused while recording, so only another app can hold the key now.
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(UInt32(shortcut.carbonKeyCode), UInt32(shortcut.carbonModifiers), EventHotKeyID(signature: 0x464C4B52, id: 1),
                                         GetEventDispatcherTarget(), 0, &ref)
        if let ref { UnregisterEventHotKey(ref) }
        return status == noErr ? nil : String(localized: "Another app is already using this shortcut.")
    }
}
