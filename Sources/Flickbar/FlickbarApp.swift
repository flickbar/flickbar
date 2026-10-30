import AppKit
import ApplicationServices
import FlickbarCore
import ServiceManagement
import Sparkle
import SwiftUI

@main @MainActor
enum Main {
    static func main() {
        // AppKit mirrors its layout only when the system language is right to left, not when just this app is set
        // to Persian; ask for it for this run (the argument domain isn't saved).
        if let language = Bundle.main.preferredLocalizations.first,
           Locale.Language(identifier: language).characterDirection == .rightToLeft {
            var arguments = UserDefaults.standard.volatileDomain(forName: UserDefaults.argumentDomain)
            arguments["AppleTextDirection"] = true
            UserDefaults.standard.setVolatileDomain(arguments, forName: UserDefaults.argumentDomain)
        }
        if CommandLine.arguments.contains(Tutorial.argument) { Tutorial.runPracticeApp() }
        FlickbarApp.main()
    }
}

struct FlickbarApp: App {
    @State private var state = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuContent(state: state)
        } label: {
            // Without a label VoiceOver reads the symbol's name ("Hand Drawing A Line").
            Image(systemName: state.isActive ? "hand.draw" : "hand.raised.slash")
                .accessibilityLabel(state.isActive ? String(localized: "Flickbar") : String(localized: "Flickbar, off"))
        }
        Settings {
            SettingsView(state: state)
        }
    }
}

/// Kept short, as the HIG asks of menu bar extras: status, the contextual per-app switch, Settings, Quit.
private struct MenuContent: View {
    @Bindable var state: AppState
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        if state.isTrusted {
            Toggle("Title Bar Gestures", isOn: $state.isEnabled)
        } else {
            Button("Grant Accessibility Access…") { state.showWelcome() }
        }
        if let app = state.frontmostApp, let id = app.bundleIdentifier {
            Toggle(String(format: String(localized: "Turn Off in %@"), app.localizedName ?? id), isOn: state.excludedBinding(id))
        }
        Divider()
        Button("Settings…") {
            // A menu bar app isn't active, so its Settings window would otherwise open behind other apps.
            NSApp.activate()
            openSettings()
        }
        .keyboardShortcut(",")
        if state.isTrusted { Button("Gesture Tutorial…") { Tutorial.open() } }
        Button("Check for Updates…") {
            NSApp.activate()
            state.updater.checkForUpdates(nil)
        }
        Divider()
        Button("Quit Flickbar") { NSApp.terminate(nil) }.keyboardShortcut("q")
    }
}

@MainActor @Observable
final class AppState {
    private(set) var isTrusted = AXIsProcessTrusted()
    var isEnabled = UserDefaults.standard.object(forKey: "enabled") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "enabled")
            tap.isEnabled = isEnabled && isTrusted
        }
    }
    var isActive: Bool { isEnabled && isTrusted }

    var launchAtLogin = SMAppService.mainApp.status == .enabled {
        didSet {
            do {
                if launchAtLogin { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                // Fails when run outside an app bundle (e.g. `swift run`); show the real state instead.
                logger.error("launch at login change failed: \(error.localizedDescription, privacy: .public)")
                launchAtLogin = SMAppService.mainApp.status == .enabled
            }
        }
    }

    /// Sparkle, reading the signed feed named in Info.plist. Daily checks stay off until the user turns them on.
    let updater = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil)
    var checkForUpdates: Bool {
        get { access(keyPath: \.checkForUpdates); return updater.updater.automaticallyChecksForUpdates }
        set { withMutation(keyPath: \.checkForUpdates) { updater.updater.automaticallyChecksForUpdates = newValue } }
    }

    var excludedApps = GestureTap.excludedApps {
        didSet { GestureTap.excludedApps = excludedApps }
    }
    var gestureMap: [String: String] = {
        GestureTap.migratePreferences()
        Shortcuts.migratePreferences()
        return GestureTap.gestureMap
    }() {
        didSet { GestureTap.gestureMap = gestureMap }
    }

    /// The app the user was last in (Flickbar's menu never becomes frontmost itself, but guard anyway).
    private(set) var frontmostApp = NSWorkspace.shared.frontmostApplication

    func excludedBinding(_ bundleID: String) -> Binding<Bool> {
        Binding(
            get: { self.excludedApps.contains(bundleID) },
            set: { if $0 { self.excludedApps.insert(bundleID) } else { self.excludedApps.remove(bundleID) } })
    }

    /// The id of the action `gesture` does (`ActionMap.off` when turned off).
    func actionBinding(_ gesture: TrackpadGesture, onDock: Bool = false) -> Binding<String> {
        let key = ActionMap.key(gesture, onDock: onDock)
        let defaultID = (onDock ? gesture.defaultDockAction : gesture.defaultAction)?.id ?? ActionMap.off
        return Binding(
            get: { ActionMap.action(for: gesture, onDock: onDock, overrides: self.gestureMap)?.id ?? ActionMap.off },
            set: { self.gestureMap[key] = $0 == defaultID ? nil : $0 })
    }

    var commandSwipeEnabled: Bool {
        get { gestureMap[ActionMap.commandSwipe] != ActionMap.off }
        set { gestureMap[ActionMap.commandSwipe] = newValue ? nil : ActionMap.off }
    }

    private let tap = GestureTap()
    private var trustPoll: Timer?

    init() {
        NSApp?.setActivationPolicy(.accessory)
        Shortcuts.install()
        // Fails outside an app bundle (`swift run`), where there's nothing to update.
        do { try updater.updater.start() } catch { logger.error("updater: \(error.localizedDescription, privacy: .public)") }
        // Before 0.10 Flickbar asked GitHub itself; carry the user's choice over to Sparkle once.
        if let old = UserDefaults.standard.object(forKey: "checkForUpdates") as? Bool {
            checkForUpdates = old
            UserDefaults.standard.removeObject(forKey: "checkForUpdates")
        }
        logger.notice("launched, accessibility trusted: \(self.isTrusted, privacy: .public)")
        if isTrusted {
            tap.isEnabled = isEnabled
        } else {
            waitForTrust()
            DispatchQueue.main.async { self.showWelcome() }
        }
        // `open Flickbar.app --args --welcome` previews the first-run window without revoking access.
        if CommandLine.arguments.contains("--welcome") { DispatchQueue.main.async { self.showWelcome() } }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            MainActor.assumeIsolated {
                if let app, app.processIdentifier != getpid() { self?.frontmostApp = app }
            }
        }
    }

    func showWelcome() { WelcomeWindow.show(state: self) }

    func requestAccess() {
        // The prompt adds Flickbar to the Accessibility list; the pane lets the user switch it on.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    /// macOS gives no callback when access is granted, so check once a second until it is.
    private func waitForTrust() {
        trustPoll = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, AXIsProcessTrusted() else { return }
                self.trustPoll?.invalidate()
                self.isTrusted = true
                self.tap.isEnabled = self.isEnabled
            }
        }
    }
}
