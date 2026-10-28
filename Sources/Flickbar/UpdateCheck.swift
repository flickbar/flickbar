import Foundation

/// Asks GitHub for the latest release. Only used when the user turns on update checks.
enum UpdateCheck {
    struct Release: Equatable {
        let version: String
        let page: URL
    }

    static func latestRelease() async -> Release? {
        let api = URL(string: "https://api.github.com/repos/flickbar/flickbar/releases/latest")!
        do {
            let (data, _) = try await URLSession.shared.data(from: api)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tag = json["tag_name"] as? String,
                  let page = (json["html_url"] as? String).flatMap(URL.init(string:)) else { return nil }
            return Release(version: tag, page: page)
        } catch {
            logger.error("update check failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}
