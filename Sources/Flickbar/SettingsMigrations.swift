import FlickbarCore

/// Every change to how preferences are stored, in release order. Append; never edit, reorder or renumber a step
/// that has shipped (see CONTRIBUTING.md, "Stored preferences").
@MainActor
enum SettingsMigrations {
    static let all = [
        // 0.2's per-group on/off switches become `gestureMap` entries.
        SettingsMigration(version: 1) { _ in GestureTap.migratePreferences() },
        // 0.9 split `minimize` from restore-or-minimize; 0.9 to 0.11 recorded this with `migratedRestoreShortcut`.
        SettingsMigration(version: 2, legacyFlag: "migratedRestoreShortcut") { _ in Shortcuts.migratePreferences() },
    ]

    static func run() { SettingsMigrator.run(all) }
}
