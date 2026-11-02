import Foundation

/// Reads CHANGELOG.md (Keep a Changelog format), which ships in the app for What's New.
/// scripts/release.sh extracts sections with the same rules in awk; change both together.
public enum Changelog {
    /// The body of the `## [version]` section, without its heading, link references or surrounding blank lines;
    /// nil when there's no such section or it's empty.
    public static func section(for version: String, in markdown: String) -> String? {
        var lines: [Substring] = []
        var inSection = false
        for line in markdown.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.hasPrefix("## ") {
                inSection = line.hasPrefix("## [\(version)]")
            } else if inSection, !isLinkReference(line) {
                lines.append(line)
            }
        }
        let body = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return body.isEmpty ? nil : body
    }

    /// Whether to show What's New at launch. `lastSeen` is the version it was last shown for (nil if never);
    /// `isFirstLaunch` means there are no saved settings yet: a new install, not an update from a version
    /// before What's New existed.
    public static func shouldShowWhatsNew(lastSeen: String?, current: String, isFirstLaunch: Bool) -> Bool {
        guard let lastSeen else { return !isFirstLaunch }
        return lastSeen != current
    }

    /// `[0.1.0]: https://…`, the link definitions at the end of the file.
    private static func isLinkReference(_ line: Substring) -> Bool {
        line.hasPrefix("[") && line.contains("]: ")
    }
}
