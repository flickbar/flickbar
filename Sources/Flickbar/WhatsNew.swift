import AppKit
import FlickbarCore
import SwiftUI

/// The running version's notes from CHANGELOG.md (copied into the app by scripts/bundle.sh). Shown once after an
/// update, and from the menu and Settings → About.
@MainActor
enum WhatsNew {
    /// The version What's New was last shown for (or, on a new install, the version first launched).
    private static let lastSeenKey = "whatsNewLastSeenVersion"
    private static let changelogURL = URL(string: "https://github.com/flickbar/flickbar/blob/main/CHANGELOG.md")!
    private static var window: NSWindow?

    private static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    private static var notes: String? {
        guard let url = Bundle.main.url(forResource: "CHANGELOG", withExtension: "md"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return Changelog.section(for: version, in: text)
    }

    /// Call first thing at launch: a new install is told apart from an update by having no saved settings yet.
    /// shortcut: someone updating from before 0.10 who never saved a setting looks like a new install and misses
    /// one What's New; fine while every 0.10+ install has Sparkle's keys saved.
    static func showIfUpdated() {
        let defaults = UserDefaults.standard
        let saved = defaults.persistentDomain(forName: Bundle.main.bundleIdentifier ?? "") ?? [:]
        let show = Changelog.shouldShowWhatsNew(
            lastSeen: defaults.string(forKey: lastSeenKey), current: version, isFirstLaunch: saved.isEmpty)
        defaults.set(version, forKey: lastSeenKey)
        // Not for builds without notes for their version (a development build, say).
        if show, notes != nil { DispatchQueue.main.async { open() } }
    }

    static func open() {
        if window == nil {
            let view = WhatsNewView(version: version, notes: notes, changelogURL: changelogURL) { window?.close() }
            let w = NSWindow(contentViewController: NSHostingController(rootView: view))
            w.title = String(localized: "What's New")
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            w.center()
            window = w
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}

private struct WhatsNewView: View {
    let version: String
    let notes: String?
    let changelogURL: URL
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 56, height: 56)
                    .accessibilityHidden(true)
                Text(String(format: String(localized: "What's New in Flickbar %@"), version)).font(.title2.bold())
            }
            if let notes {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(notes.split(separator: "\n").enumerated()), id: \.offset) { _, line in
                            NoteLine(line: String(line))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, 8)
                }
                .frame(height: 300)
                // The notes are in English, so they read left to right in every language.
                .environment(\.layoutDirection, .leftToRight)
            } else {
                Text("No notes for this version.").foregroundStyle(.secondary)
            }
            HStack {
                Link("Full Changelog", destination: changelogURL)
                Spacer()
                Button("Done", action: close).keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 520)
    }
}

/// One line of a changelog section: a `###` heading, a `- ` bullet or a paragraph, with inline Markdown.
private struct NoteLine: View {
    let line: String

    var body: some View {
        if line.hasPrefix("### ") {
            Text(line.dropFirst(4)).font(.headline).padding(.top, 4)
        } else if line.hasPrefix("- ") {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(verbatim: "•").accessibilityHidden(true)
                markdown(line.dropFirst(2))
            }
        } else {
            markdown(line[...])
        }
    }

    private func markdown(_ text: Substring) -> some View {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return Text((try? AttributedString(markdown: String(text), options: options)) ?? AttributedString(text))
            .fixedSize(horizontal: false, vertical: true)
    }
}
