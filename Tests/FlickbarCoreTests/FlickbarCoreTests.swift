import CoreGraphics
import Testing
@testable import FlickbarCore

@Suite struct RecognizerTests {
    @Test func smallJitterIsIgnored() {
        var r = GestureRecognizer()
        for _ in 0..<5 { r.addScroll(dx: 3, dy: 2) }
        #expect(r.strokes.isEmpty)
    }

    @Test func horizontalSwipe() {
        var r = GestureRecognizer()
        for _ in 0..<10 { r.addScroll(dx: -6, dy: 1) }
        #expect(r.strokes == [.left])
    }

    @Test func diagonalIsRejected() {
        var r = GestureRecognizer()
        for _ in 0..<20 { r.addScroll(dx: 5, dy: 5) }
        #expect(r.strokes.isEmpty)
    }

    @Test func continuingSameDirectionDoesNotRepeat() {
        var r = GestureRecognizer()
        for _ in 0..<40 { r.addScroll(dx: 8, dy: 0) }
        #expect(r.strokes == [.right])
    }

    @Test func twoStrokeQuarter() {
        var r = GestureRecognizer()
        for _ in 0..<10 { r.addScroll(dx: -8, dy: 0) }
        for _ in 0..<10 { r.addScroll(dx: 0, dy: -8) }
        #expect(r.strokes == [.left, .up])
        #expect(ActionMap.action(for: r.strokes) == .snap(.topLeft))
    }

    @Test func pinch() {
        var r = GestureRecognizer()
        for _ in 0..<10 { r.addMagnification(-0.02) }
        #expect(r.strokes == [.pinchIn])
        #expect(ActionMap.action(for: r.strokes) == .close)
    }

    @Test func resetClears() {
        var r = GestureRecognizer()
        for _ in 0..<10 { r.addScroll(dx: 8, dy: 0) }
        r.reset()
        #expect(r.strokes.isEmpty)
    }
}

@Suite struct GeometryTests {
    let screen = CGRect(x: 0, y: 25, width: 1000, height: 800)
    let window = CGRect(x: 10, y: 40, width: 400, height: 300)

    @Test func halvesTileTheScreen() {
        let l = SnapGeometry.frame(for: .leftHalf, in: screen, current: window)
        let r = SnapGeometry.frame(for: .rightHalf, in: screen, current: window)
        #expect(l == CGRect(x: 0, y: 25, width: 500, height: 800))
        #expect(r == CGRect(x: 500, y: 25, width: 500, height: 800))
    }

    @Test func quartersWithGap() {
        let br = SnapGeometry.frame(for: .bottomRight, in: screen, current: window, gap: 10)
        #expect(br == CGRect(x: 505, y: 430, width: 485, height: 385))
    }

    @Test func centerKeepsSize() {
        let c = SnapGeometry.frame(for: .center, in: screen, current: window)
        #expect(c == CGRect(x: 300, y: 275, width: 400, height: 300))
    }

    @Test func unknownSequenceHasNoAction() {
        #expect(ActionMap.action(for: [.left, .right]) == nil)
        #expect(ActionMap.action(for: []) == nil)
    }
}
