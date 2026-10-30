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
        .frame(width: 600)
    }
}

// MARK: General

private struct GeneralSettings: View {
    @Bindable var state: AppState
    @AppStorage("gap") private var gap = 0
    @AppStorage("haptics") private var haptics = true
    @AppStorage("preview") private var preview = true
    @State private var language = AppLanguage.chosen

    var body: some View {
        Form {
            Section {
                HStack(spacing: 12) {
                    Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 48, height: 48)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Flickbar").font(.headline)
                        Text(status).font(.callout).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if state.isTrusted {
                        Toggle("Gestures", isOn: $state.isEnabled).toggleStyle(.switch).labelsHidden()
                    } else {
                        Button("Grant Access…") { state.showWelcome() }.buttonStyle(.borderedProminent)
                    }
                }
                .padding(.vertical, 4)
            }
            Section("Windows") {
                Picker("Space between windows", selection: $gap) {
                    Text("None").tag(0)
                    Text("Small").tag(6)
                    Text("Medium").tag(12)
                    Text("Large").tag(20)
                }
                Toggle("Show where the window will go", isOn: $preview)
                Toggle("Tap the trackpad when a gesture is recognized", isOn: $haptics)
            }
            Section {
                Picker("Language", selection: $language) {
                    Text("Same as System").tag("")
                    Divider()
                    // Each language in its own words, as macOS lists them.
                    ForEach(AppLanguage.all, id: \.code) { Text(verbatim: $0.name).tag($0.code) }
                }
                .onChange(of: language) { _, new in AppLanguage.chosen = new }
                if language != AppLanguage.atLaunch {
                    HStack {
                        Text("Restart Flickbar to use the new language.").foregroundStyle(.secondary)
                        Spacer()
                        Button("Restart Now") { AppLanguage.relaunch() }
                    }
                }
            }
            Section {
                Toggle("Open at login", isOn: $state.launchAtLogin)
                Toggle("Check for updates", isOn: $state.checkForUpdates)
            } footer: {
                Text("Once a day, Flickbar reads its update list from flickbar.github.io, sending only its version number. Updates are signed and checked before they install.").footnote()
            }
        }
        .formStyle(.grouped)
        .frame(height: 500)
    }

    private var status: String {
        if !state.isTrusted { return String(localized: "Needs Accessibility access to move windows.") }
        return state.isEnabled ? String(localized: "On. Swipe on a window's title bar.") : String(localized: "Off.")
    }
}

private extension Text {
    /// Secondary explanatory text under a section.
    func footnote() -> some View {
        foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: Action names

/// Menu titles and pictures for actions, shared by the Gestures and Shortcuts tabs.
enum ActionNames {
    /// Menu sections: halves and fill, thirds, quarters, window actions, app actions.
    static var groups: [[WindowAction]] {
        [[.snap(.leftHalf), .snap(.rightHalf), .snap(.maximize), .snap(.center)],
         [.snap(.leftThird), .snap(.centerThird), .snap(.rightThird), .snap(.leftTwoThirds), .snap(.rightTwoThirds)],
         [.snap(.topLeft), .snap(.topRight), .snap(.bottomLeft), .snap(.bottomRight)],
         [.minimize, .restoreOrMinimize, .toggleFullscreen, .close, .nextWindow],
         appActions]
    }
    static let groupTitles = [String(localized: "Halves"), String(localized: "Thirds"), String(localized: "Quarters"),
                               String(localized: "Window"), String(localized: "App")]

    /// The actions that make sense on a Dock icon, which has an app but no window.
    static var appActions: [WindowAction] { [.appWindows, .hideApp, .quitApp] }

    static func title(_ action: WindowAction) -> String {
        switch action {
        case .snap(.leftHalf): String(localized: "Left Half")
        case .snap(.rightHalf): String(localized: "Right Half")
        case .snap(.maximize): String(localized: "Fill Screen")
        case .snap(.center): String(localized: "Center")
        case .snap(.leftThird): String(localized: "Left Third")
        case .snap(.centerThird): String(localized: "Middle Third")
        case .snap(.rightThird): String(localized: "Right Third")
        case .snap(.leftTwoThirds): String(localized: "Left Two-Thirds")
        case .snap(.rightTwoThirds): String(localized: "Right Two-Thirds")
        case .snap(.topLeft): String(localized: "Top-Left Quarter")
        case .snap(.topRight): String(localized: "Top-Right Quarter")
        case .snap(.bottomLeft): String(localized: "Bottom-Left Quarter")
        case .snap(.bottomRight): String(localized: "Bottom-Right Quarter")
        case .minimize: String(localized: "Minimize")
        case .restoreOrMinimize: String(localized: "Restore or Minimize")
        case .toggleFullscreen: String(localized: "Full Screen")
        case .close: String(localized: "Close Window")
        case .nextWindow: String(localized: "Next Window of App")
        case .appWindows: String(localized: "Show App's Windows")
        case .hideApp: String(localized: "Hide App")
        case .quitApp: String(localized: "Quit App")
        case .moveToDisplay(.left): String(localized: "Move to Display on the Left")
        case .moveToDisplay(.right): String(localized: "Move to Display on the Right")
        case .moveToDisplay(.up): String(localized: "Move to Display Above")
        case .moveToDisplay(.down): String(localized: "Move to Display Below")
        case .moveToDisplay: String(localized: "Move to Another Display")
        }
    }

    /// Symbol for actions that don't put the window somewhere `LayoutGlyph` can draw.
    static func symbol(_ action: WindowAction?) -> String {
        switch action {
        case .minimize: "dock.arrow.down.rectangle"
        case .restoreOrMinimize: "arrow.uturn.backward"
        case .toggleFullscreen: "arrow.up.left.and.arrow.down.right"
        case .close: "xmark"
        case .nextWindow: "macwindow.on.rectangle"
        case .appWindows: "square.grid.2x2"
        case .hideApp: "eye.slash"
        case .quitApp: "power"
        case .moveToDisplay(.left): "arrow.left"
        case .moveToDisplay(.right): "arrow.right"
        case .moveToDisplay(.up): "arrow.up"
        case .moveToDisplay(.down): "arrow.down"
        default: "nosign"
        }
    }
}

/// A small screen showing where an action puts the window, or a symbol for actions that don't move it.
struct LayoutGlyph: View {
    let action: WindowAction?
    var symbol: String?
    var width: CGFloat = 56

    var body: some View {
        let height = (width * 0.64).rounded()
        let corner = width * 0.1
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: corner).fill(.quaternary)
            RoundedRectangle(cornerRadius: corner).strokeBorder(.tertiary, lineWidth: 1)
            if symbol == nil, case .snap(let target) = action {
                let inset = width * 0.05
                let screen = CGRect(x: inset, y: inset, width: width - 2 * inset, height: height - 2 * inset)
                let r = SnapGeometry.frame(for: target, in: screen, current: screen.insetBy(dx: screen.width * 0.22, dy: screen.height * 0.2),
                                           gap: width * 0.03)
                RoundedRectangle(cornerRadius: corner * 0.5)
                    .fill(Color.accentColor.gradient)
                    .frame(width: r.width, height: r.height)
                    .offset(x: r.minX, y: r.minY)
            } else {
                Image(systemName: symbol ?? ActionNames.symbol(action))
                    .font(.system(size: height * 0.42, weight: .semibold))
                    .foregroundStyle(action == nil && symbol == nil ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.tint))
                    .frame(width: width, height: height)
            }
        }
        .frame(width: width, height: height)
        // A picture of the screen: left stays left in right-to-left languages.
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityHidden(true)
    }
}

// MARK: Gestures

private struct GestureSettings: View {
    @Bindable var state: AppState
    @AppStorage("anywhereModifier") private var anywhereModifier = "option"
    @State private var onDock = false
    @Environment(\.layoutDirection) private var direction

    private static let titleBarGestures: [(TrackpadGesture, String, String)] = [
        (.swipeLeft, String(localized: "Swipe Left"), "arrow.left"),
        (.swipeUp, String(localized: "Swipe Up"), "arrow.up"),
        (.swipeRight, String(localized: "Swipe Right"), "arrow.right"),
        (.swipeLeftUp, String(localized: "Left, Then Up"), "arrow.up.left"),
        (.swipeDown, String(localized: "Swipe Down"), "arrow.down"),
        (.swipeRightUp, String(localized: "Right, Then Up"), "arrow.up.right"),
        (.swipeLeftDown, String(localized: "Left, Then Down"), "arrow.down.left"),
        (.doubleTap, String(localized: "Double-Tap"), "hand.tap"),
        (.swipeRightDown, String(localized: "Right, Then Down"), "arrow.down.right"),
        (.pinchIn, String(localized: "Pinch In"), "arrow.down.right.and.arrow.up.left"),
        (.pinchOut, String(localized: "Pinch Out"), "arrow.up.left.and.arrow.down.right"),
    ]
    private static let dockGestures: [(TrackpadGesture, String, String)] = [
        (.swipeLeft, String(localized: "Swipe Left"), "arrow.left"),
        (.swipeUp, String(localized: "Swipe Up"), "arrow.up"),
        (.swipeRight, String(localized: "Swipe Right"), "arrow.right"),
        (.pinchIn, String(localized: "Pinch In"), "arrow.down.right.and.arrow.up.left"),
        (.swipeDown, String(localized: "Swipe Down"), "arrow.down"),
        (.pinchOut, String(localized: "Pinch Out"), "arrow.up.left.and.arrow.down.right"),
    ]

    var body: some View {
        VStack(spacing: 14) {
            Picker("Where", selection: $onDock) {
                Text("On a Window's Title Bar").tag(false)
                Text("On an App's Dock Icon").tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(onDock ? Self.dockGestures : Self.titleBarGestures, id: \.0) { gesture, title, symbol in
                    tile(title, symbol) {
                        LayoutGlyph(action: ActionMap.action(for: gesture, onDock: onDock, overrides: state.gestureMap))
                    } detail: {
                        picker(gesture)
                    }
                }
                if !onDock {
                    tile(String(localized: "Touch and Hold"), "hand.point.up.left") {
                        LayoutGlyph(action: nil, symbol: "square.grid.3x3")
                    } detail: {
                        Text("Pick from a grid").foregroundStyle(.secondary)
                    }
                }
            }
            // The tiles sit where their gestures point (Swipe Left on the left), even in right-to-left languages.
            .environment(\.layoutDirection, .leftToRight)

            if onDock {
                Text("Works on the icons of apps that are running.").footnote()
            } else {
                VStack(spacing: 8) {
                    Toggle("Hold ⌘ and swipe to move a window to another display", isOn: $state.commandSwipeEnabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Picker("Gesture anywhere in a window while holding", selection: $anywhereModifier) {
                        Text("⌥ Option").tag("option")
                        Text("⌃ Control").tag("control")
                        Text("Off").tag("off")
                    }
                    .fixedSize()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            Spacer(minLength: 0)
            HStack(alignment: .firstTextBaseline) {
                if onDock {
                    Spacer()
                } else {
                    Text("Repeat a swipe to a half or Fill Screen to cycle through thirds. Press Esc before lifting your fingers to cancel.").footnote()
                }
                Button("Restore Defaults") { state.gestureMap = [:] }
                    .disabled(state.gestureMap.isEmpty)
            }
        }
        .padding(20)
        // Dock icons have fewer gestures; fit the window to them.
        .frame(height: onDock ? 440 : 660)
    }

    private func tile(_ title: String, _ symbol: String, @ViewBuilder glyph: () -> some View,
                      @ViewBuilder detail: () -> some View) -> some View {
        VStack(spacing: 6) {
            glyph()
            Label(title, systemImage: symbol).font(.callout.weight(.medium)).lineLimit(1).frame(height: 20)
            detail().frame(height: 22)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.separator))
        .environment(\.layoutDirection, direction)
    }

    private func picker(_ gesture: TrackpadGesture) -> some View {
        Picker("Action", selection: state.actionBinding(gesture, onDock: onDock)) {
            ForEach(onDock ? [[.nextWindow] + ActionNames.appActions] : ActionNames.groups, id: \.self) { group in
                ForEach(group, id: \.id) { Text(ActionNames.title($0)).tag($0.id) }
                Divider()
            }
            Text("Nothing").tag(ActionMap.off)
        }
        .labelsHidden()
        .controlSize(.small)
        .frame(maxWidth: 160)
    }
}

// MARK: Shortcuts

private struct ShortcutSettings: View {
    var body: some View {
        Form {
            ForEach(Array(zip(ActionNames.groupTitles, ActionNames.groups)), id: \.0) { title, group in
                Section(title) { recorders(group) }
            }
            Section {
                recorders(Shortcuts.displayMoves)
            } header: {
                Text("Displays")
            } footer: {
                Text("Shortcuts act on the frontmost window. Repeat a half or Fill Screen shortcut to cycle through thirds.").footnote()
            }
        }
        .formStyle(.grouped)
        .frame(height: 660)
    }

    private func recorders(_ actions: [WindowAction]) -> some View {
        ForEach(actions, id: \.id) { action in
            LabeledContent {
                KeyboardShortcuts.Recorder(for: Shortcuts.name(action))
            } label: {
                HStack(spacing: 10) {
                    LayoutGlyph(action: action, width: 30)
                    Text(ActionNames.title(action))
                }
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
        panel.prompt = String(localized: "Add")
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
            Text(String(format: String(localized: "Version %@"), version)).foregroundStyle(.secondary)
            Text("Snap, resize and move windows with trackpad gestures on their title bars.")
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
            HStack(spacing: 16) {
                Link("Source Code", destination: URL(string: "https://github.com/flickbar/flickbar")!)
                Link("Report an Issue", destination: URL(string: "https://github.com/flickbar/flickbar/issues")!)
            }
            .padding(.top, 4)
            Text("Made by [Parsa Kamalipour](https://github.com/benymaxparsa)")
                .padding(.top, 8)
            Text("Free and open source under the GNU GPL v3.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
        }
        .padding(30)
        .frame(maxWidth: .infinity)
        .frame(height: 400)
    }
}
