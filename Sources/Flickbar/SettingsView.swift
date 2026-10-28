import AppKit
import FlickbarCore
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Bindable var state: AppState

    var body: some View {
        TabView {
            GeneralSettings(state: state)
                .tabItem { Label("General", systemImage: "gearshape") }
            GestureSettings(state: state)
                .tabItem { Label("Gestures", systemImage: "hand.draw") }
            AppSettings(state: state)
                .tabItem { Label("Apps", systemImage: "app.badge.checkmark") }
            AboutSettings()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 500)
    }
}

// MARK: General

private struct GeneralSettings: View {
    @Bindable var state: AppState
    @AppStorage("gap") private var gap = 0
    @AppStorage("haptics") private var haptics = true

    var body: some View {
        Form {
            Section {
                Toggle("Title bar gestures", isOn: $state.isEnabled)
                    .disabled(!state.isTrusted)
                LabeledContent("Accessibility access") {
                    if state.isTrusted {
                        Label("Granted", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button("Grant Access…") { state.showWelcome() }
                    }
                }
            }
            Section {
                Picker("Space between windows", selection: $gap) {
                    Text("None").tag(0)
                    Text("Small").tag(6)
                    Text("Medium").tag(12)
                    Text("Large").tag(20)
                }
                Toggle("Haptic feedback", isOn: $haptics)
            } footer: {
                Text("A light tap from the trackpad confirms a gesture before you lift your fingers.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Section {
                Toggle("Open at login", isOn: $state.launchAtLogin)
            }
        }
        .formStyle(.grouped)
        .frame(height: 330)
    }
}

// MARK: Gestures

private struct GestureSettings: View {
    @Bindable var state: AppState

    var body: some View {
        Form {
            Section("Snap") {
                row(.halves, "Left or right half", "Swipe left or right", "rectangle.lefthalf.inset.filled")
                row(.quarters, "Quarter", "Swipe left or right, then up or down", "rectangle.split.2x2")
                row(.fill, "Fill the screen", "Swipe up", "rectangle.inset.filled")
                row(.center, "Center", "Double-tap with two fingers", "rectangle.center.inset.filled")
                row(.restoreOrMinimize, "Restore or minimize", "Swipe down", "arrow.uturn.backward.square")
            }
            Section {
                row(.fullScreen, "Full screen", "Pinch out", "arrow.up.left.and.arrow.down.right.square")
                row(.close, "Close", "Pinch in", "xmark.square")
                row(.moveToDisplay, "Move to another display", "Hold ⌘ and swipe toward the display", "display.2")
            } header: {
                Text("Window")
            } footer: {
                Text("Use two fingers with the pointer over a window's title bar. Swiping down on a snapped window restores its earlier size. Press Esc before lifting your fingers to cancel.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .formStyle(.grouped)
        .frame(height: 640)
    }

    private func row(_ kind: GestureKind, _ title: String, _ how: String, _ symbol: String) -> some View {
        Toggle(isOn: state.gestureBinding(kind)) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    Text(how).font(.callout).foregroundStyle(.secondary)
                }
            } icon: {
                // Fixed width so titles line up whatever the symbol's shape.
                Image(systemName: symbol)
                    .foregroundStyle(.tint)
                    .font(.title2)
                    .frame(width: 30)
            }
        }
    }
}

// MARK: Apps

private struct AppSettings: View {
    @Bindable var state: AppState
    @State private var selection = Set<String>()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Title bar gestures are turned off in these apps.")
            VStack(spacing: 0) {
                List(state.excludedApps.sorted(by: { appName($0) < appName($1) }), id: \.self, selection: $selection) { id in
                    AppRow(bundleID: id)
                }
                .listStyle(.bordered(alternatesRowBackgrounds: true))
                .overlay {
                    if state.excludedApps.isEmpty {
                        ContentUnavailableView("No Apps", systemImage: "app.dashed",
                                               description: Text("Click + to choose an app."))
                    }
                }
                // The standard add/remove bar under a list.
                HStack(spacing: 0) {
                    Button(action: addApps) { Image(systemName: "plus").frame(width: 24, height: 22) }
                        .help("Add an app")
                    Divider().frame(height: 16)
                    Button { state.excludedApps.subtract(selection); selection = [] } label: {
                        Image(systemName: "minus").frame(width: 24, height: 22)
                    }
                    .disabled(selection.isEmpty)
                    .help("Remove the selected apps")
                    Spacer()
                }
                .buttonStyle(.borderless)
                .padding(.horizontal, 4)
                .background(.quaternary.opacity(0.5))
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.separator))
            Text("You can also turn gestures off for the current app from the Flickbar menu.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(height: 380)
    }

    private func addApps() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Add"
        guard panel.runModal() == .OK else { return }
        let ids = panel.urls.compactMap { Bundle(url: $0)?.bundleIdentifier }.filter { $0 != Bundle.main.bundleIdentifier }
        state.excludedApps.formUnion(ids)
    }
}

private func appURL(_ bundleID: String) -> URL? { NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) }

private func appName(_ bundleID: String) -> String {
    appURL(bundleID).map { FileManager.default.displayName(atPath: $0.path).replacingOccurrences(of: ".app", with: "") } ?? bundleID
}

private struct AppRow: View {
    let bundleID: String

    var body: some View {
        HStack(spacing: 8) {
            if let url = appURL(bundleID) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().frame(width: 20, height: 20)
            } else {
                Image(systemName: "app.dashed").frame(width: 20, height: 20)
            }
            Text(appName(bundleID))
            if appURL(bundleID) == nil {
                Text("Not installed").foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: About

private struct AboutSettings: View {
    private let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"

    var body: some View {
        VStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
            Text("Flickbar").font(.title.bold())
            Text("Version \(version)").foregroundStyle(.secondary)
            Text("Snap, resize and move windows with trackpad gestures on their title bars.")
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
            HStack(spacing: 16) {
                Link("Source Code", destination: URL(string: "https://github.com/flickbar/flickbar")!)
                Link("Report an Issue", destination: URL(string: "https://github.com/flickbar/flickbar/issues")!)
            }
            .padding(.top, 4)
            Text("Free and open source under the GNU GPL v3.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
        }
        .padding(30)
        .frame(maxWidth: .infinity)
        .frame(height: 330)
    }
}
