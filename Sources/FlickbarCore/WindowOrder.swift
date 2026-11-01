import CoreGraphics

public enum WindowOrder {
    /// The process owning the frontmost ordinary window (layer 0) in `windows`, a front-to-back
    /// `CGWindowListCopyWindowInfo` list, skipping `excluded`'s windows. Nil if there is none.
    public static func frontmostOwner(in windows: [[String: Any]], excluding excluded: pid_t) -> pid_t? {
        windows.lazy.compactMap { window -> pid_t? in
            guard (window[kCGWindowLayer as String] as? Int) == 0, let pid = window[kCGWindowOwnerPID as String] as? Int,
                  pid_t(pid) != excluded else { return nil }
            return pid_t(pid)
        }.first
    }
}
