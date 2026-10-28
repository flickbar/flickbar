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
                Button("Grant Access…") { state.requestAccess() }
            }
            Divider()
            Picker("Window Gap", selection: $gap) {
                Text("None").tag(0)
                Text("Small").tag(6)
                Text("Medium").tag(12)
                Text("Large").tag(20)
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
                NSLog("Flickbar: launch at login change failed: \(error)")
                launchAtLogin = SMAppService.mainApp.status == .enabled
            }
        }
    }

    private let tap = GestureTap()
    private var trustPoll: Timer?

    init() {
        NSApp?.setActivationPolicy(.accessory)
        if isTrusted { tap.isEnabled = isEnabled } else { waitForTrust() }
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
