import AppKit
import FlickbarCore
import SwiftUI

/// Gesture practice. The practice window runs in a second copy of Flickbar (`--practice`), because macOS doesn't
/// let an app reach its own windows through the Accessibility API; the main copy reports what it does there.
@MainActor
enum Tutorial {
    static let argument = "--practice"
    private static let performed = Notification.Name("io.github.flickbar.Flickbar.performed")

    /// Opens the practice window, or brings it forward if it's already open.
    static func open() {
        let copies = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "")
        // Only the practice copy has a Dock icon; another normal copy (say, a development build) has none.
        if let practice = copies.first(where: { $0.processIdentifier != getpid() && $0.activationPolicy == .regular }) {
            practice.activate()
            return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        configuration.arguments = [argument]
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, error in
            if let error { logger.error("tutorial didn't open: \(error.localizedDescription, privacy: .public)") }
        }
    }

    /// Tells the practice window that `actionID` ran on `window`, if `window` is the practice window.
    static func report(_ actionID: String, on window: AXWindow) {
        var pid: pid_t = 0
        guard let own = Bundle.main.bundleIdentifier, AXUIElementGetPid(window.element, &pid) == .success,
              NSRunningApplication(processIdentifier: pid)?.bundleIdentifier == own else { return }
        DistributedNotificationCenter.default().postNotificationName(performed, object: actionID, deliverImmediately: true)
    }

    /// The practice copy's whole life: one window, and quitting when it closes.
    static func runPracticeApp() -> Never {
        let app = NSApplication.shared
        // A Dock icon, so swiping down has somewhere to minimize the window to.
        app.setActivationPolicy(.regular)
        // Just enough menu for ⌘W and ⌘Q.
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: String(localized: "Close Window"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        appMenu.addItem(withTitle: String(localized: "Quit Tutorial"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let appItem = NSMenuItem()
        appItem.submenu = appMenu
        app.mainMenu = NSMenu()
        app.mainMenu?.addItem(appItem)
        let delegate = PracticeDelegate()
        app.delegate = delegate
        app.run()
        exit(0)
    }

    @MainActor
    private final class PracticeDelegate: NSObject, NSApplicationDelegate {
        private let progress = TutorialProgress()
        private var window: NSWindow?

        func applicationDidFinishLaunching(_ notification: Notification) {
            let w = NSWindow(contentViewController: NSHostingController(rootView: TutorialView(progress: progress)))
            w.title = String(localized: "Try Flickbar's Gestures")
            // Resizable, or the Accessibility API can't snap it.
            w.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            w.setContentSize(NSSize(width: 520, height: 440))
            w.center()
            w.makeKeyAndOrderFront(nil)
            window = w
            NSApp.activate()
            DistributedNotificationCenter.default().addObserver(forName: performed, object: nil, queue: .main) { [weak self] note in
                guard let id = note.object as? String else { return }
                MainActor.assumeIsolated { self?.completed(id) }
            }
        }

        private func completed(_ id: String) {
            let steps = TutorialStep.allCases.filter { $0.isDone(by: id) && !progress.done.contains($0) }
            progress.done.formUnion(steps)
            for step in steps {
                AccessibilityNotification.Announcement(String(format: String(localized: "%@ done"), step.title)).post()
            }
            // Bring the window back from the Dock so the tutorial can go on.
            if steps.contains(.minimize) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { self.window?.deminiaturize(nil) }
            }
        }

        func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    }
}

@MainActor @Observable
private final class TutorialProgress {
    var done: Set<TutorialStep> = []
}

private struct TutorialView: View {
    let progress: TutorialProgress
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var finished: Bool { progress.done.count == TutorialStep.allCases.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Try it on this window").font(.title2.bold())
                Text("Put the pointer on this window's title bar and use two fingers on the trackpad.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(TutorialStep.allCases, id: \.self) { step in
                let done = progress.done.contains(step)
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Image(systemName: done ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(done ? AnyShapeStyle(.green) : AnyShapeStyle(.tertiary))
                        .contentTransition(.symbolEffect(.replace))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(step.title).font(.headline)
                        Text(step.how).font(.callout).foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityValue(done ? String(localized: "Done") : String(localized: "Not done yet"))
            }
            Spacer(minLength: 0)
            HStack {
                if finished { Label("You're all set.", systemImage: "hand.thumbsup.fill").foregroundStyle(.green) }
                Spacer()
                Button(finished ? "Done" : "Skip") { NSApp.terminate(nil) }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 340, maxWidth: .infinity, minHeight: 300, maxHeight: .infinity, alignment: .topLeading)
        .animation(reduceMotion ? nil : .snappy, value: progress.done)
    }
}

private extension TutorialStep {
    var title: String {
        switch self {
        case .leftHalf: String(localized: "Left half")
        case .rightHalf: String(localized: "Right half")
        case .fill: String(localized: "Fill the screen")
        case .quarter: String(localized: "A quarter")
        case .grid: String(localized: "Pick a layout")
        case .minimize: String(localized: "Minimize")
        }
    }

    var how: String {
        switch self {
        case .leftHalf: String(localized: "Swipe left.")
        case .rightHalf: String(localized: "Swipe right.")
        case .fill: String(localized: "Swipe up.")
        case .quarter: String(localized: "Swipe left or right, then up or down.")
        case .grid: String(localized: "Rest two fingers until a grid appears, move to a cell, then lift.")
        case .minimize: String(localized: "Swipe down. The window comes right back.")
        }
    }
}
