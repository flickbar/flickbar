import AppKit
import ApplicationServices
import ServiceManagement
import SwiftUI

@main
struct FlickbarApp: App {
    @State private var state = AppState()
    @AppStorage("gap") private var gap = 0

    var body: some Scene {
        MenuBarExtra("Flickbar", systemImage: "hand.draw") {
            if state.isTrusted {
                Toggle("Enabled", isOn: $state.isEnabled)
            } else {
                Text("Accessibility access needed")
                Text("Already on? Remove Flickbar with − and add it again.")
                Button("Grant Access…") { state.requestAccess() }
            }
            Menu("Gestures on a Title Bar") {
                Text("Swipe left / right — half screen")
                Text("Swipe up — fill screen")
                Text("Swipe sideways, then up or down — quarter")
                Text("Swipe down — restore, or minimize")
                Text("Pinch in — close · Pinch out — full screen")
                Text("Double-tap with two fingers — center")
                Text("⌘ + swipe — move to another display")
                Text("Esc before lifting — cancel")
            }
            Divider()
            Picker("Window Gap", selection: $gap) {
                Text("None").tag(0)
                Text("Small").tag(6)
                Text("Medium").tag(12)
                Text("Large").tag(20)
            }
            if let app = state.frontmostApp, let id = app.bundleIdentifier {
                Toggle("Disable in \(app.localizedName ?? id)", isOn: state.excludedBinding(id))
            }
            Toggle("Launch at Login", isOn: $state.launchAtLogin)
            Divider()
            Button("Quit Flickbar") { NSApp.terminate(nil) }.keyboardShortcut("q")
        }
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

    /// The app the user was last in (Flickbar's menu never becomes frontmost itself, but guard anyway).
    private(set) var frontmostApp = NSWorkspace.shared.frontmostApplication

    func excludedBinding(_ bundleID: String) -> Binding<Bool> {
        Binding(
            get: { GestureTap.excludedApps.contains(bundleID) },
            set: { exclude in
                var apps = GestureTap.excludedApps
                if exclude { apps.insert(bundleID) } else { apps.remove(bundleID) }
                GestureTap.excludedApps = apps
            })
    }

    private let tap = GestureTap()
    private var trustPoll: Timer?

    init() {
        NSApp?.setActivationPolicy(.accessory)
        logger.notice("launched, accessibility trusted: \(self.isTrusted, privacy: .public)")
        if isTrusted { tap.isEnabled = isEnabled } else { waitForTrust() }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            MainActor.assumeIsolated {
                if let app, app.processIdentifier != getpid() { self?.frontmostApp = app }
            }
        }
    }

    func requestAccess() {
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
