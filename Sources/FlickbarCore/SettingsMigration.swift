import Foundation

/// One step that brings stored preferences from an older layout to the current one.
public struct SettingsMigration {
    /// Position in the sequence; steps run once each, in ascending order. Never renumber a released step.
    public let version: Int
    /// The ad-hoc "already done" flag this step used before schema versions existed, if any. When it is set the
    /// step is recorded as done without running, so a release that predates the schema version isn't re-migrated.
    public let legacyFlag: String?
    public let apply: (UserDefaults) -> Void

    public init(version: Int, legacyFlag: String? = nil, apply: @escaping (UserDefaults) -> Void) {
        self.version = version
        self.legacyFlag = legacyFlag
        self.apply = apply
    }
}

/// Runs `SettingsMigration`s once each, so renaming or reshaping a stored key never drops what a user set.
public enum SettingsMigrator {
    /// Highest migration applied so far. Never lowered: a newer build's version survives a downgrade.
    public static let versionKey = "settingsSchemaVersion"

    public static func run(_ migrations: [SettingsMigration], on defaults: UserDefaults = .standard) {
        var current = defaults.integer(forKey: versionKey)
        for step in migrations.sorted(by: { $0.version < $1.version }) where step.version > current {
            if step.legacyFlag.map(defaults.bool(forKey:)) != true { step.apply(defaults) }
            defaults.set(step.version, forKey: versionKey)
            current = step.version
        }
    }
}
