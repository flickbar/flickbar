/// Why a key combination can't be a global shortcut, judged by its modifiers alone.
public enum ShortcutRule: Equatable, Sendable {
    /// No ⌘, ⌃ or ⌥: the key would stop typing in every app.
    case needsModifier
    /// ⌘ (or ⌘⇧) without ⌃ or ⌥: would take over an app command such as ⌘Q, ⌘W or ⌘C in every app.
    case commandOnly

    public static func problem(command: Bool, control: Bool, option: Bool, isFunctionKey: Bool) -> ShortcutRule? {
        guard !isFunctionKey, !control, !option else { return nil }
        return command ? .commandOnly : .needsModifier
    }
}
