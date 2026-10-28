import AppKit
import FlickbarCore
import KeyboardShortcuts
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
            ShortcutSettings()
                .tabItem { Label("Shortcuts", systemImage: "command") }
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
    @AppStorage("preview") private var preview = true

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
                Toggle("Show where the window will go", isOn: $preview)
                Toggle("Haptic feedback", isOn: $haptics)
            } footer: {
                Text("A preview and a light tap from the trackpad confirm a gesture before you lift your fingers.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Section {
                Toggle("Open at login", isOn: $state.launchAtLogin)
                Toggle("Check for updates", isOn: $state.checkForUpdates)
            } footer: {
                Text("Once a day, Flickbar asks GitHub for the latest version number and shows it in the menu if it's newer. It sends nothing else.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .formStyle(.grouped)
        .frame(height: 450)
    }
}

// MARK: Action names

/// Menu titles for actions, shared by the Gestures and Shortcuts tabs.
enum ActionNames {
    /// Menu sections: halves and fill, thirds, quarters, window actions, app actions.
    static var groups: [[WindowAction]] {
        [[.snap(.leftHalf), .snap(.rightHalf), .snap(.maximize), .snap(.center)],
         [.snap(.leftThird), .snap(.centerThird), .snap(.rightThird), .snap(.leftTwoThirds), .snap(.rightTwoThirds)],
         [.snap(.topLeft), .snap(.topRight), .snap(.bottomLeft), .snap(.bottomRight)],
         [.minimize, .toggleFullscreen, .close, .nextWindow],
         appActions]
    }

    /// The actions that make sense on a Dock icon, which has an app but no window.
    static var appActions: [WindowAction] { [.appWindows, .hideApp, .quitApp] }

    static func title(_ action: WindowAction) -> String {
        switch action {
        case .snap(.leftHalf): "Left Half"
        case .snap(.rightHalf): "Right Half"
        case .snap(.maximize): "Fill Screen"
        case .snap(.center): "Center"
        case .snap(.leftThird): "Left Third"
        case .snap(.centerThird): "Middle Third"
        case .snap(.rightThird): "Right Third"
        case .snap(.leftTwoThirds): "Left Two-Thirds"
        case .snap(.rightTwoThirds): "Right Two-Thirds"
        case .snap(.topLeft): "Top-Left Quarter"
        case .snap(.topRight): "Top-Right Quarter"
        case .snap(.bottomLeft): "Bottom-Left Quarter"
        case .snap(.bottomRight): "Bottom-Right Quarter"
        case .minimize: "Restore or Minimize"
        case .toggleFullscreen: "Full Screen"
        case .close: "Close Window"
        case .nextWindow: "Next Window of App"
        case .appWindows: "Show App's Windows"
        case .hideApp: "Hide App"
        case .quitApp: "Quit App"
        case .moveToDisplay(.left): "Move to Display on the Left"
        case .moveToDisplay(.right): "Move to Display on the Right"
        case .moveToDisplay(.up): "Move to Display Above"
        case .moveToDisplay(.down): "Move to Display Below"
        case .moveToDisplay: "Move to Another Display"
        }
    }
}

// MARK: Gestures

private struct GestureSettings: View {
    @Bindable var state: AppState
    @AppStorage("anywhereModifier") private var anywhereModifier = "option"

    var body: some View {
        Form {
            Section {
                row(.swipeLeft, "Swipe left", "arrow.left")
                row(.swipeRight, "Swipe right", "arrow.right")
                row(.swipeUp, "Swipe up", "arrow.up")
                row(.swipeDown, "Swipe down", "arrow.down")
            } header: {
                Text("Swipe")
            } footer: {
                footnote("Repeat a swipe to a half for ⅔ and ⅓, or to fill the screen for the middle third. Swiping down on a snapped window restores its earlier size.")
            }
            Section("Swipe sideways, then up or down") {
                row(.swipeLeftUp, "Left and up", "arrow.up.left")
                row(.swipeRightUp, "Right and up", "arrow.up.right")
                row(.swipeLeftDown, "Left and down", "arrow.down.left")
                row(.swipeRightDown, "Right and down", "arrow.down.right")
            }
            Section("Tap and pinch") {
                row(.doubleTap, "Double-tap", "hand.tap")
                row(.pinchOut, "Pinch out", "arrow.up.left.and.arrow.down.right")
                row(.pinchIn, "Pinch in", "arrow.down.right.and.arrow.up.left")
                Toggle(isOn: $state.commandSwipeEnabled) {
                    label("Move to another display", "Hold ⌘ and swipe toward the display", "display.2")
                }
            }
            Section {
                row(.swipeUp, "Swipe up", "arrow.up", onDock: true)
                row(.swipeDown, "Swipe down", "arrow.down", onDock: true)
                row(.swipeLeft, "Swipe left", "arrow.left", onDock: true)
                row(.swipeRight, "Swipe right", "arrow.right", onDock: true)
                row(.pinchIn, "Pinch in", "arrow.down.right.and.arrow.up.left", onDock: true)
                row(.pinchOut, "Pinch out", "arrow.up.left.and.arrow.down.right", onDock: true)
            } header: {
                Text("On an app's Dock icon")
            } footer: {
                footnote("Works on apps that are running.")
            }
            Section {
                Picker("Use gestures anywhere in a window while holding", selection: $anywhereModifier) {
                    Text("⌥ Option").tag("option")
                    Text("⌃ Control").tag("control")
                    Text("Off").tag("off")
                }
            } footer: {
                footnote("Otherwise gestures work with the pointer over a window's title bar. Press Esc before lifting your fingers to cancel.")
            }
            Section {
                Button("Restore Defaults") { state.gestureMap = [:] }
                    .disabled(state.gestureMap.isEmpty)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .formStyle(.grouped)
        .frame(height: 640)
    }

    private func row(_ gesture: TrackpadGesture, _ title: String, _ symbol: String, onDock: Bool = false) -> some View {
        Picker(selection: state.actionBinding(gesture, onDock: onDock)) {
            ForEach(onDock ? [[.nextWindow] + ActionNames.appActions] : ActionNames.groups, id: \.self) { group in
                ForEach(group, id: \.id) { Text(ActionNames.title($0)).tag($0.id) }
                Divider()
            }
            Text("Nothing").tag(ActionMap.off)
        } label: {
            label(title, nil, symbol)
        }
    }

    private func label(_ title: String, _ detail: String?, _ symbol: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let detail { Text(detail).font(.callout).foregroundStyle(.secondary) }
            }
        } icon: {
            // Fixed width so titles line up whatever the symbol's shape.
            Image(systemName: symbol).foregroundStyle(.tint).frame(width: 24)
        }
    }

    private func footnote(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: Shortcuts

private struct ShortcutSettings: View {
    var body: some View {
        Form {
            ForEach(ActionNames.groups, id: \.self) { group in
                Section { recorders(group) }
            }
            Section {
                recorders(Shortcuts.displayMoves)
            } footer: {
                Text("Shortcuts act on the frontmost window. Repeat a half or Fill Screen shortcut to cycle through thirds.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .formStyle(.grouped)
        .frame(height: 640)
    }

    private func recorders(_ actions: [WindowAction]) -> some View {
        ForEach(actions, id: \.id) { action in
            KeyboardShortcuts.Recorder(LocalizedStringKey(ActionNames.title(action)), name: Shortcuts.name(action))
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
        .frame(height: 370)
    }
}
