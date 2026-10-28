import CoreGraphics

/// Remembers each window's frame from before Flickbar first moved it, so it can be put back.
public struct RestoreMemory<Key: Hashable> {
    private var entries: [Key: (original: CGRect, placed: CGRect)] = [:]
    /// Apps may nudge a frame after a move (e.g. terminals round to character cells), so compare loosely.
    private let tolerance: CGFloat = 8

    public init() {}

    /// Record a move of `key` from `before` to `after`. The first original is kept across repeated snaps.
    public mutating func record(_ key: Key, from before: CGRect, to after: CGRect) {
        entries[key] = (entries[key]?.original ?? before, after)
    }

    /// The frame to restore if the window is still where Flickbar put it.
    public func original(_ key: Key, current: CGRect) -> CGRect? {
        guard let entry = entries[key],
              abs(entry.placed.minX - current.minX) <= tolerance,
              abs(entry.placed.minY - current.minY) <= tolerance else { return nil }
        return entry.original
    }

    /// Like `original`, but forgets the entry either way.
    public mutating func takeOriginal(_ key: Key, current: CGRect) -> CGRect? {
        defer { entries[key] = nil }
        return original(key, current: current)
    }
}
