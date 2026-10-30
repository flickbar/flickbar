import AppKit
import SwiftUI

/// First-run window that explains why Flickbar needs Accessibility access before asking for it,
/// and turns into a confirmation once access is granted.
@MainActor
enum WelcomeWindow {
    private static var window: NSWindow?

    static func show(state: AppState) {
        if window == nil {
            let view = WelcomeView(state: state) { window?.close() }
            let w = NSWindow(contentViewController: NSHostingController(rootView: view))
            w.title = String(localized: "Welcome to Flickbar")
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            w.center()
            window = w
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}

private struct WelcomeView: View {
    let state: AppState
    let close: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 88, height: 88)
            VStack(spacing: 6) {
                Text("Welcome to Flickbar").font(.title2.bold())
                Text("Swipe or pinch with two fingers on any window's title bar to snap, resize and move it.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            GroupBox {
                if state.isTrusted {
                    Label("Accessibility access is on. You're ready to go.", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(6)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Flickbar needs Accessibility access", systemImage: "accessibility")
                            .font(.headline)
                        Text("macOS requires this permission for apps that arrange windows. Flickbar uses it only to move and resize the windows you gesture on. It doesn't collect or send any data.")
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Click Open System Settings, then turn on Flickbar. If it's already on, select it, click − to remove it, and add it again.")
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(6)
                }
            }
            HStack {
                Spacer()
                if state.isTrusted {
                    Button("Skip", action: close).keyboardShortcut(.cancelAction)
                    Button("Try the Gestures") {
                        Tutorial.open()
                        close()
                    }
                    .keyboardShortcut(.defaultAction)
                } else {
                    Button("Later", action: close).keyboardShortcut(.cancelAction)
                    Button("Open System Settings") { state.requestAccess() }.keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(24)
        .frame(width: 460)
        .animation(.default, value: state.isTrusted)
    }
}
