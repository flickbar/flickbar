import Foundation

public enum Version {
    /// Whether release tag `tag` (e.g. "v0.6.1") is a later version than `current` (e.g. "0.6.0").
    public static func isNewer(_ tag: String, than current: String) -> Bool {
        let latest = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        return latest.compare(current, options: .numeric) == .orderedDescending
    }
}
