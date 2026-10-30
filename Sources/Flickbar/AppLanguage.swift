import AppKit

/// Flickbar's own interface language, kept where macOS keeps the per-app choice from
/// System Settings → General → Language & Region → Applications, so both stay in step.
@MainActor
enum AppLanguage {
    static let all: [(code: String, name: String)] = [("en", "English"), ("fr", "Français"), ("fa", "فارسی")]

    /// The chosen language code, or "" to follow the system. System Settings may store a regional variant
    /// ("fr-CA"); only the language matters here.
    static var chosen: String {
        get {
            let own = Bundle.main.bundleIdentifier.flatMap(UserDefaults.standard.persistentDomain(forName:))
            let code = (own?["AppleLanguages"] as? [String])?.first ?? ""
            return String(code.prefix { $0 != "-" && $0 != "_" })
        }
        set {
            if newValue.isEmpty { UserDefaults.standard.removeObject(forKey: "AppleLanguages") }
            else { UserDefaults.standard.set([newValue], forKey: "AppleLanguages") }
        }
    }

    /// What `chosen` was when Flickbar started, i.e. the language it's showing now.
    static let atLaunch = chosen

    /// Quits and opens Flickbar again once this copy has gone, since the language is read at launch.
    static func relaunch() {
        // The tutorial's copy would keep the old language, and `open` would just bring it forward.
        let copies = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "")
        copies.filter { $0.processIdentifier != getpid() && $0.activationPolicy == .regular }.forEach { $0.terminate() }
        let reopen = Process()
        reopen.executableURL = URL(fileURLWithPath: "/bin/sh")
        // Gives up after 10 s, so a quit that never happens can't leave a reopen pending.
        reopen.arguments = ["-c", "i=0; while kill -0 \(getpid()) 2>/dev/null; do i=$((i+1)); [ $i -gt 100 ] && exit; sleep 0.1; done; /usr/bin/open -n \"$0\"",
                            Bundle.main.bundlePath]
        do {
            try reopen.run()
            NSApp.terminate(nil)
        } catch {
            logger.error("relaunch failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
