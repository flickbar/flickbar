import Foundation
import Testing
@testable import FlickbarCore

@Suite struct SettingsMigrationTests {
    /// A throwaway defaults domain, so tests never touch the user's real preferences.
    private func scratch(_ contents: [String: Any] = [:]) -> (defaults: UserDefaults, domain: String, cleanup: () -> Void) {
        let name = "flickbar.tests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defaults.setPersistentDomain(contents, forName: name)
        return (defaults, name, { defaults.removePersistentDomain(forName: name) })
    }

    /// Every key Flickbar 0.11.0 stores, with non-default values (the shape of a long-time user's plist).
    private let v011: [String: Any] = [
        "gap": 12, "haptics": false, "preview": false, "anywhereModifier": "control", "enabled": false,
        "excludedApps": ["com.apple.Terminal"],
        "gestureMap": ["swipeDown": "restoreOrMinimize", "commandSwipe": "none"],
        "migratedRestoreShortcut": true,
        "KeyboardShortcuts_minimize": "{\"carbonKeyCode\":46,\"carbonModifiers\":4352}",
        "AppleLanguages": ["fr"],
        "SUEnableAutomaticChecks": true,
    ]

    final class Log { var versions: [Int] = [] }

    private func step(_ log: Log, _ version: Int, legacyFlag: String? = nil) -> SettingsMigration {
        SettingsMigration(version: version, legacyFlag: legacyFlag) { _ in log.versions.append(version) }
    }

    @Test func runsInOrderOnceAndRecordsVersion() {
        let (defaults, _, cleanup) = scratch(); defer { cleanup() }
        let log = Log()
        let steps = [step(log, 2), step(log, 1)]
        SettingsMigrator.run(steps, on: defaults)
        SettingsMigrator.run(steps, on: defaults)
        #expect(log.versions == [1, 2])
        #expect(defaults.integer(forKey: SettingsMigrator.versionKey) == 2)
    }

    @Test func onlyNewerStepsRun() {
        let (defaults, _, cleanup) = scratch([SettingsMigrator.versionKey: 1]); defer { cleanup() }
        let log = Log()
        SettingsMigrator.run([step(log, 1), step(log, 2), step(log, 3)], on: defaults)
        #expect(log.versions == [2, 3])
        #expect(defaults.integer(forKey: SettingsMigrator.versionKey) == 3)
    }

    @Test func downgradeNeverLowersVersionOrRunsSteps() {
        let (defaults, _, cleanup) = scratch([SettingsMigrator.versionKey: 5]); defer { cleanup() }
        let log = Log()
        SettingsMigrator.run([step(log, 1), step(log, 2)], on: defaults)
        #expect(log.versions.isEmpty)
        #expect(defaults.integer(forKey: SettingsMigrator.versionKey) == 5)
    }

    @Test func legacyFlagSkipsTheStepButRecordsIt() {
        let (defaults, _, cleanup) = scratch(["done": true]); defer { cleanup() }
        let log = Log()
        SettingsMigrator.run([step(log, 1, legacyFlag: "done"), step(log, 2, legacyFlag: "other")], on: defaults)
        #expect(log.versions == [2])
        #expect(defaults.integer(forKey: SettingsMigrator.versionKey) == 2)
    }

    @Test func renameMigrationKeepsTheValue() {
        let (defaults, _, cleanup) = scratch(["oldGap": 7]); defer { cleanup() }
        let rename = SettingsMigration(version: 1) { d in
            guard let value = d.object(forKey: "oldGap") else { return }
            d.set(value, forKey: "gap")
            d.removeObject(forKey: "oldGap")
        }
        SettingsMigrator.run([rename], on: defaults)
        #expect(defaults.integer(forKey: "gap") == 7)
        #expect(defaults.object(forKey: "oldGap") == nil)
    }

    @Test func version011PreferencesSurviveUntouched() {
        let (defaults, domain, cleanup) = scratch(v011); defer { cleanup() }
        // 0.11 already set the restore-shortcut flag, so that step must be recorded without running again.
        let log = Log()
        SettingsMigrator.run([step(log, 1), step(log, 2, legacyFlag: "migratedRestoreShortcut")], on: defaults)
        #expect(log.versions == [1])
        let after = defaults.persistentDomain(forName: domain) ?? [:]
        for (key, value) in v011 { #expect((after[key] as? NSObject) == (value as? NSObject), "\(key) changed") }
        #expect(after[SettingsMigrator.versionKey] as? Int == 2)
        #expect(defaults.integer(forKey: "gap") == 12)
        #expect(defaults.bool(forKey: "haptics") == false)
        #expect(defaults.stringArray(forKey: "excludedApps") == ["com.apple.Terminal"])
    }

    @Test func version09PreferencesWithoutTheFlagStillRunTheStep() {
        var old = v011
        old["migratedRestoreShortcut"] = nil
        let (defaults, _, cleanup) = scratch(old); defer { cleanup() }
        let log = Log()
        SettingsMigrator.run([step(log, 1), step(log, 2, legacyFlag: "migratedRestoreShortcut")], on: defaults)
        #expect(log.versions == [1, 2])
        #expect(defaults.bool(forKey: "migratedRestoreShortcut"))
    }
}
