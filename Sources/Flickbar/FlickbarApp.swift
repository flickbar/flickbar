import AppKit
import ApplicationServices
import SwiftUI

@main
struct FlickbarApp: App {
    @State private var state = AppState()

    var body: some Scene {
        MenuBarExtra("Flickbar", systemImage: "hand.draw") {
            if state.isTrusted {
                Toggle("Enabled", isOn: $state.isEnabled)
            } else {
                Text("Accessibility access needed")
                Button("Grant Access…") { state.requestAccess() }
            }
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
