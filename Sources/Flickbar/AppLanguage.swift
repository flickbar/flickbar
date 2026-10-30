import AppKit

/// Flickbar's own interface language, kept where macOS keeps the per-app choice from
/// System Settings → General → Language & Region → Applications, so both stay in step.
@MainActor
enum AppLanguage {
    static let all: [(code: String, name: String)] = [("en", "English"), ("fr", "Français"), ("fa", "فارسی")]

    /// The chosen language code, or "" to follow the system.
    static var chosen: String {
        get {
            let own = Bundle.main.bundleIdentifier.flatMap(UserDefaults.standard.persistentDomain(forName:))
            return (own?["AppleLanguages"] as? [String])?.first ?? ""
        }
        set {
            if newValue.isEmpty { UserDefaults.standard.removeObject(forKey: "AppleLanguages") }
            else { UserDefaults.standard.set([newValue], forKey: "AppleLanguages") }
        }
    }

    /// Quits and opens Flickbar again once this copy has gone, since the language is read at launch.
    static func relaunch() {
        let reopen = Process()
        reopen.executableURL = URL(fileURLWithPath: "/bin/sh")
        reopen.arguments = ["-c", "while kill -0 \(getpid()) 2>/dev/null; do sleep 0.1; done; /usr/bin/open \"$0\"", Bundle.main.bundlePath]
        do {
            try reopen.run()
            NSApp.terminate(nil)
        } catch {
            logger.error("relaunch failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
