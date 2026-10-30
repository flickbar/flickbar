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
        if let practice = copies.first(where: { $0.processIdentifier != getpid() }) {
            practice.activate()
            return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        configuration.arguments = [argument]
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration)
    }

    /// Tells the practice window that `actionID` ran on `window`, if `window` is the practice window.
    static func report(_ actionID: String, on window: AXWindow) {
        var pid: pid_t = 0
        guard AXUIElementGetPid(window.element, &pid) == .success,
              NSRunningApplication(processIdentifier: pid)?.bundleIdentifier == Bundle.main.bundleIdentifier else { return }
        DistributedNotificationCenter.default().postNotificationName(performed, object: actionID, deliverImmediately: true)
    }

    /// The practice copy's whole life: one window, and quitting when it closes.
    static func runPracticeApp() -> Never {
        let app = NSApplication.shared
        // A Dock icon, so swiping down has somewhere to minimize the window to.
        app.setActivationPolicy(.regular)
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
            w.title = "Try Flickbar's Gestures"
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
            let steps = TutorialStep.allCases.filter { $0.isDone(by: id) }
            progress.done.formUnion(steps)
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
                    VStack(alignment: .leading, spacing: 1) {
                        Text(step.title).font(.headline)
                        Text(step.how).font(.callout).foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityValue(done ? "Done" : "Not done yet")
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
        case .leftHalf: "Left half"
        case .rightHalf: "Right half"
        case .fill: "Fill the screen"
        case .quarter: "A quarter"
        case .grid: "Pick a layout"
        case .minimize: "Minimize"
        }
    }

    var how: String {
        switch self {
        case .leftHalf: "Swipe left."
        case .rightHalf: "Swipe right."
        case .fill: "Swipe up."
        case .quarter: "Swipe left or right, then up or down."
        case .grid: "Rest two fingers until a grid appears, move to a cell, then lift."
        case .minimize: "Swipe down. The window comes right back."
        }
    }
}
