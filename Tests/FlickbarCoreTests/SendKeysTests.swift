import CoreGraphics
import Testing
@testable import FlickbarCore

@Suite struct SendKeysTests {
    @Test func idRoundTrips() {
        let copy = WindowAction.sendKeys(keyCode: 8, modifiers: 256) // ⌘C
        #expect(copy.id == "keys.8.256")
        #expect(WindowAction(id: copy.id) == copy)
        #expect(WindowAction(id: "keys.36.0") == .sendKeys(keyCode: 36, modifiers: 0)) // plain Return
    }

    @Test(arguments: ["keys", "keys.8", "keys.x.256", "keys.8.256.1", "keys.8.y"])
    func malformedIDsAreRejected(id: String) {
        #expect(WindowAction(id: id) == nil)
    }

    @Test func gestureOverrideSendsKeys() {
        let overrides = [ActionMap.key(.swipeLeft): "keys.9.768"]
        #expect(ActionMap.action(for: [.left], overrides: overrides) == .sendKeys(keyCode: 9, modifiers: 768))
    }

    @Test func carbonModifiersBecomeEventFlags() {
        #expect(eventFlags(carbonModifiers: 0) == [])
        #expect(eventFlags(carbonModifiers: 256) == .maskCommand)
        #expect(eventFlags(carbonModifiers: 256 | 512 | 2048 | 4096) == [.maskCommand, .maskShift, .maskAlternate, .maskControl])
    }
}
