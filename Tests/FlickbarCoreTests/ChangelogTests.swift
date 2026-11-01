import Foundation
import Testing
@testable import FlickbarCore

@Suite struct ChangelogTests {
    let sample = """
        # Changelog

        ## [Unreleased]

        ### Added

        - Something new.

        ## [0.10.0] - 2026-10-30

        ### Fixed

        - Ten.

        ## [0.1.0] - 2026-10-28

        - First.

        ## [0.2.0] - 2026-10-28

        [Unreleased]: https://example.com/compare/v0.10.0...HEAD
        [0.1.0]: https://example.com/v0.1.0
        """

    @Test func extractsSectionBody() {
        #expect(Changelog.section(for: "0.10.0", in: sample) == "### Fixed\n\n- Ten.")
        #expect(Changelog.section(for: "Unreleased", in: sample) == "### Added\n\n- Something new.")
    }

    @Test func versionPrefixDoesNotMatchLongerVersion() {
        // "0.1.0" must not pick up "0.10.0".
        #expect(Changelog.section(for: "0.1.0", in: sample) == "- First.")
    }

    @Test func missingOrEmptySectionIsNil() {
        #expect(Changelog.section(for: "9.9.9", in: sample) == nil)
        // Only link references follow it, and those aren't notes.
        #expect(Changelog.section(for: "0.2.0", in: sample) == nil)
    }

    @Test func shippedChangelogHasEveryRelease() throws {
        let url = URL(filePath: #filePath).deletingLastPathComponent().appending(path: "../../CHANGELOG.md")
        let text = try String(contentsOf: url, encoding: .utf8)
        for v in ["0.1.0", "0.2.0", "0.3.0", "0.4.0", "0.5.0", "0.6.0", "0.7.0", "0.7.1", "0.8.0", "0.9.0", "0.10.0", "0.11.0"] {
            #expect(Changelog.section(for: v, in: text) != nil, "no notes for \(v)")
        }
    }

    @Test func whatsNewShowsOnceAfterUpdateOnly() {
        #expect(!Changelog.shouldShowWhatsNew(lastSeen: nil, current: "0.12.0", isFirstLaunch: true))
        #expect(Changelog.shouldShowWhatsNew(lastSeen: nil, current: "0.12.0", isFirstLaunch: false))
        #expect(Changelog.shouldShowWhatsNew(lastSeen: "0.11.0", current: "0.12.0", isFirstLaunch: false))
        #expect(!Changelog.shouldShowWhatsNew(lastSeen: "0.12.0", current: "0.12.0", isFirstLaunch: false))
    }
}
