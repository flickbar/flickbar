import Foundation

/// The interface language a stored language code stands for: the base language ("fr-CA" → "fr"), plus the script
/// for Chinese ("zh-TW" → "zh-Hant"), since Simplified and Traditional are separate translations. "" stays "".
public func interfaceLanguage(_ code: String) -> String {
    let language = Locale.Language(identifier: code)
    guard let base = language.languageCode?.identifier else { return "" }
    guard base == "zh" else { return base }
    // The full form fills in a script missing from region-only codes like "zh-TW" or "zh-CN".
    return "zh-" + (Locale.Language(identifier: language.maximalIdentifier).script?.identifier ?? "Hans")
}
