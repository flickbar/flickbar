// End-to-end test against the running Flickbar: posts synthetic trackpad gestures on a TextEdit
// window it creates and checks the resulting frames. Moves windows on screen; run via scripts/livetest.sh.
import AppKit
import ApplicationServices

// MARK: Accessibility helpers

func attr(_ e: AXUIElement, _ name: String) -> CFTypeRef? {
    var v: CFTypeRef?
    return AXUIElementCopyAttributeValue(e, name as CFString, &v) == .success ? v : nil
}

func frame(_ w: AXUIElement) -> CGRect {
    var p = CGPoint.zero, s = CGSize.zero
    AXValueGetValue(attr(w, kAXPositionAttribute) as! AXValue, .cgPoint, &p)
    AXValueGetValue(attr(w, kAXSizeAttribute) as! AXValue, .cgSize, &s)
    return CGRect(origin: p, size: s)
}

func setFrame(_ w: AXUIElement, _ r: CGRect) {
    var p = r.origin, s = r.size
    AXUIElementSetAttributeValue(w, kAXPositionAttribute as CFString, AXValueCreate(.cgPoint, &p)!)
    AXUIElementSetAttributeValue(w, kAXSizeAttribute as CFString, AXValueCreate(.cgSize, &s)!)
}

func bool(_ w: AXUIElement, _ name: String) -> Bool { (attr(w, name) as? Bool) ?? false }

// MARK: Synthetic events

func scroll(_ at: CGPoint, dx: Double, dy: Double, phase: Int64, flags: CGEventFlags = []) {
    let e = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2,
                    wheel1: Int32(dy), wheel2: Int32(dx), wheel3: 0)!
    e.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
    e.setIntegerValueField(.scrollWheelEventScrollPhase, value: phase)
    e.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: Int64(dy))
    e.setIntegerValueField(.scrollWheelEventPointDeltaAxis2, value: Int64(dx))
    e.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: dy)
    e.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2, value: dx)
    e.location = at
    e.flags = flags
    e.post(tap: .cghidEventTap)
    usleep(8000)
}

/// Each stroke is finger travel in points (+x right, +y down). Not natural-scrolling, so content delta = -finger.
func swipe(_ at: CGPoint, _ strokes: [(Double, Double)], flags: CGEventFlags = [], escape: Bool = false) {
    CGWarpMouseCursorPosition(at)
    usleep(50000)
    var first = true
    for (fx, fy) in strokes {
        for _ in 0..<12 {
            scroll(at, dx: -fx / 12, dy: -fy / 12, phase: first ? 1 : 2, flags: flags)
            first = false
        }
    }
    if escape {
        CGEvent(keyboardEventSource: nil, virtualKey: 53, keyDown: true)!.post(tap: .cghidEventTap)
        CGEvent(keyboardEventSource: nil, virtualKey: 53, keyDown: false)!.post(tap: .cghidEventTap)
        usleep(20000)
    }
    scroll(at, dx: 0, dy: 0, phase: 4, flags: flags)
    usleep(400000)
}

func pinch(_ at: CGPoint, total: Double) {
    // Undocumented CGEvent fields carried by the system's own gesture events.
    func post(_ v: Double, _ phase: Int64) {
        let e = CGEvent(source: nil)!
        e.type = CGEventType(rawValue: 29)!
        e.setIntegerValueField(CGEventField(rawValue: 55)!, value: 29)
        e.setIntegerValueField(CGEventField(rawValue: 110)!, value: 8)
        e.setDoubleValueField(CGEventField(rawValue: 113)!, value: v)
        e.setIntegerValueField(CGEventField(rawValue: 132)!, value: phase)
        e.location = at
        e.post(tap: .cghidEventTap)
        usleep(10000)
    }
    CGWarpMouseCursorPosition(at)
    usleep(50000)
    post(0, 1)
    for _ in 0..<15 { post(total / 15, 2) }
    post(0, 4)
    usleep(600000)
}

// MARK: Test setup

func appleScript(_ s: String) {
    var err: NSDictionary?
    NSAppleScript(source: s)!.executeAndReturnError(&err)
    if let err { print("AppleScript error: \(err)") }
}

appleScript("""
tell application "TextEdit"
    activate
    set d to make new document with properties {text:"Flickbar live test"}
end tell
""")
sleep(1)

let pid = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.TextEdit").first!.processIdentifier
let app = AXUIElementCreateApplication(pid)
let windows = attr(app, kAXWindowsAttribute) as! [AXUIElement]
let window = windows.first { (attr($0, kAXTitleAttribute) as? String)?.hasPrefix("Untitled") == true
    && (attr($0, kAXSubroleAttribute) as? String) == kAXStandardWindowSubrole }!

let primaryHeight = NSScreen.screens[0].frame.maxY
let screens = NSScreen.screens.map { s -> CGRect in
    let v = s.visibleFrame
    return CGRect(x: v.minX, y: primaryHeight - v.maxY, width: v.width, height: v.height)
}
let main = screens[0]
let start = CGRect(x: main.minX + 150, y: main.minY + 150, width: 700, height: 500)

func titlebar() -> CGPoint { let f = frame(window); return CGPoint(x: f.midX, y: f.minY + 12) }
func content() -> CGPoint { let f = frame(window); return CGPoint(x: f.midX, y: f.midY) }

var failures = 0
func near(_ a: CGRect, _ b: CGRect, _ tol: CGFloat = 2) -> Bool {
    abs(a.minX - b.minX) <= tol && abs(a.minY - b.minY) <= tol
        && abs(a.width - b.width) <= tol && abs(a.height - b.height) <= tol
}
func check(_ name: String, _ ok: Bool, _ detail: @autoclosure () -> String) {
    print(ok ? "PASS" : "FAIL", name, ok ? "" : "— \(detail())")
    if !ok { failures += 1 }
}
func expect(_ name: String, _ want: CGRect, tol: CGFloat = 2) {
    let got = frame(window)
    check(name, near(got, want, tol), "got \(got), want \(want)")
}

// Apps may refuse exact sizes (TextEdit can't shrink below its minimum); tolerances cover rounding only.
let halfW = (main.width / 2).rounded(), halfH = (main.height / 2).rounded()
UserDefaults(suiteName: "io.github.flickbar.Flickbar")!.set(0, forKey: "gap")

setFrame(window, start); usleep(300000)
swipe(titlebar(), [(-120, 0)]);           expect("swipe left → left half", CGRect(x: main.minX, y: main.minY, width: halfW, height: main.height))
swipe(titlebar(), [(120, 0)]);            expect("swipe right → right half", CGRect(x: main.minX + halfW, y: main.minY, width: halfW, height: main.height))
swipe(titlebar(), [(0, -120)]);           expect("swipe up → fill", main)
swipe(titlebar(), [(-120, 0), (0, -120)]); expect("left, up → top-left", CGRect(x: main.minX, y: main.minY, width: halfW, height: halfH))
swipe(titlebar(), [(0, 120), (120, 0)]);  expect("down, right → bottom-right", CGRect(x: main.minX + halfW, y: main.minY + halfH, width: halfW, height: halfH))
swipe(titlebar(), [(0, 120)]);            expect("swipe down → restore", start)

let before = frame(window)
swipe(titlebar(), [(-120, 0)], escape: true); expect("Esc cancels", before)
swipe(content(), [(-120, 0)]);                expect("swipe on content is ignored", before)
swipe(titlebar(), [(-60, -60)]);              expect("diagonal is ignored", before)

let prefs = UserDefaults(suiteName: "io.github.flickbar.Flickbar")!
prefs.set(["com.apple.TextEdit"], forKey: "excludedApps")
swipe(titlebar(), [(-120, 0)]);               expect("excluded app is ignored", before)
prefs.removeObject(forKey: "excludedApps")
prefs.set(["halves"], forKey: "disabledGestures")
swipe(titlebar(), [(-120, 0)]);               expect("gesture turned off in Settings is ignored", before)
prefs.removeObject(forKey: "disabledGestures")

if screens.count > 1 {
    swipe(titlebar(), [(0, -120)], flags: .maskCommand)
    check("⌘ swipe moves to another display", !main.contains(CGPoint(x: frame(window).midX, y: frame(window).midY)), "\(frame(window))")
    swipe(titlebar(), [(0, 120)], flags: .maskCommand)
    expect("⌘ swipe back → same frame", before)
}

UserDefaults(suiteName: "io.github.flickbar.Flickbar")!.set(12, forKey: "gap")
swipe(titlebar(), [(-120, 0)])
expect("gap 12 left half", CGRect(x: main.minX + 12, y: main.minY + 12, width: ((main.width - 36) / 2).rounded(), height: main.height - 24))
UserDefaults(suiteName: "io.github.flickbar.Flickbar")!.set(0, forKey: "gap")
setFrame(window, start); usleep(300000)

pinch(titlebar(), total: 0.5); sleep(1)
check("pinch out → full screen", bool(window, "AXFullScreen"), "not full screen")
AXUIElementSetAttributeValue(window, "AXFullScreen" as CFString, kCFBooleanFalse); sleep(2)

swipe(titlebar(), [(0, 120)]); usleep(500000)
check("swipe down (not snapped) → minimize", bool(window, kAXMinimizedAttribute), "not minimized")
AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse); sleep(1)
appleScript("tell application \"TextEdit\" to activate"); usleep(500000)

pinch(titlebar(), total: -0.5); usleep(500000)
let open = (attr(app, kAXWindowsAttribute) as? [AXUIElement] ?? []).contains { CFEqual($0, window) }
check("pinch in → close", !open, "window still open")
// The test document has text, so TextEdit asks to save: discard.
appleScript("tell application \"TextEdit\" to close (every document whose name starts with \"Untitled\") saving no")

print(failures == 0 ? "\nALL PASSED" : "\n\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
