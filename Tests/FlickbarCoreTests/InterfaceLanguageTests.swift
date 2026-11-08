import Testing
@testable import FlickbarCore

@Suite struct InterfaceLanguageTests {
    @Test(arguments: [
        ("", ""), ("en", "en"), ("en-US", "en"), ("fr-CA", "fr"), ("es-MX", "es"), ("es_419", "es"), ("fa_IR", "fa"),
        ("zh", "zh-Hans"), ("zh-Hans", "zh-Hans"), ("zh-Hans-CN", "zh-Hans"), ("zh-CN", "zh-Hans"),
        ("zh-Hant", "zh-Hant"), ("zh-Hant-TW", "zh-Hant"), ("zh-TW", "zh-Hant"), ("zh-HK", "zh-Hant"), ("zh_TW", "zh-Hant"),
    ])
    func mapsStoredCodeToPickerCode(code: String, expected: String) {
        #expect(interfaceLanguage(code) == expected)
    }
}
