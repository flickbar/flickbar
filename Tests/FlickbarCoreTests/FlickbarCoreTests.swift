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

    @Test func commandSwipeMovesDisplay() {
        #expect(ActionMap.action(for: [.right], command: true) == .moveToDisplay(.right))
        #expect(ActionMap.action(for: [.right, .up], command: true) == nil)
        #expect(ActionMap.action(for: [.pinchIn], command: true) == nil)
    }
}

@Suite struct GestureKindTests {
    @Test func everyStrokeSequenceMapsToItsGroup() {
        #expect(ActionMap.action(for: [.left])?.kind == .halves)
        #expect(ActionMap.action(for: [.up])?.kind == .fill)
        #expect(ActionMap.action(for: [.down, .right])?.kind == .quarters)
        #expect(ActionMap.action(for: [.down])?.kind == .restoreOrMinimize)
        #expect(ActionMap.action(for: [.pinchIn])?.kind == .close)
        #expect(ActionMap.action(for: [.pinchOut])?.kind == .fullScreen)
        #expect(ActionMap.action(for: [.up], command: true)?.kind == .moveToDisplay)
        #expect(WindowAction.snap(.center).kind == .center)
    }
}

@Suite struct RestoreTests {
    let original = CGRect(x: 100, y: 100, width: 600, height: 400)
    let half = CGRect(x: 0, y: 25, width: 500, height: 800)
    let quarter = CGRect(x: 0, y: 25, width: 500, height: 400)

    @Test func restoresFirstOriginalAfterRepeatedSnaps() {
        var m = RestoreMemory<Int>()
        m.record(1, from: original, to: half)
        m.record(1, from: half, to: quarter)
        #expect(m.takeOriginal(1, current: quarter) == original)
        #expect(m.takeOriginal(1, current: quarter) == nil)
    }

    @Test func noRestoreIfUserMovedWindow() {
        var m = RestoreMemory<Int>()
        m.record(1, from: original, to: half)
        #expect(m.takeOriginal(1, current: half.offsetBy(dx: 200, dy: 0)) == nil)
    }

    @Test func toleratesSmallAdjustments() {
        var m = RestoreMemory<Int>()
        m.record(1, from: original, to: half)
        #expect(m.takeOriginal(1, current: half.offsetBy(dx: 3, dy: 5)) == original)
    }
}

@Suite struct DisplayTests {
    let main = CGRect(x: 0, y: 0, width: 1000, height: 800)
    let right = CGRect(x: 1000, y: 0, width: 2000, height: 1000)
    let above = CGRect(x: 0, y: -900, width: 1000, height: 900)

    @Test func picksNeighborInDirection() {
        let all = [main, right, above]
        #expect(SnapGeometry.neighbor(of: main, in: all, toward: .right) == right)
        #expect(SnapGeometry.neighbor(of: main, in: all, toward: .up) == above)
        #expect(SnapGeometry.neighbor(of: main, in: all, toward: .left) == nil)
        #expect(SnapGeometry.neighbor(of: right, in: all, toward: .left) == main)
    }

    @Test func relocateRoundTripDoesNotGrow() {
        // Real layout seen in testing: laptop below an ultrawide.
        let laptop = CGRect(x: 0, y: 33, width: 1512, height: 896)
        let ultrawide = CGRect(x: -634, y: -1440, width: 3440, height: 1440)
        let window = CGRect(x: 200, y: 200, width: 700, height: 500)
        let there = SnapGeometry.relocate(window, from: laptop, to: ultrawide)
        #expect(SnapGeometry.relocate(there, from: ultrawide, to: laptop) == window)
    }

    @Test func relocateKeepsProportions() {
        let leftHalf = CGRect(x: 0, y: 0, width: 500, height: 800)
        #expect(SnapGeometry.relocate(leftHalf, from: main, to: right) == CGRect(x: 1000, y: 0, width: 1000, height: 1000))
    }
}

@Suite struct ThirdsTests {
    let screen = CGRect(x: 0, y: 0, width: 900, height: 600)
    let window = CGRect(x: 10, y: 40, width: 400, height: 300)

    func frame(_ t: SnapTarget, gap: CGFloat = 0) -> CGRect {
        SnapGeometry.frame(for: t, in: screen, current: window, gap: gap)
    }

    @Test func thirdsTileTheScreen() {
        #expect(frame(.leftThird) == CGRect(x: 0, y: 0, width: 300, height: 600))
        #expect(frame(.centerThird) == CGRect(x: 300, y: 0, width: 300, height: 600))
        #expect(frame(.rightThird) == CGRect(x: 600, y: 0, width: 300, height: 600))
        #expect(frame(.leftTwoThirds) == CGRect(x: 0, y: 0, width: 600, height: 600))
        #expect(frame(.rightTwoThirds) == CGRect(x: 300, y: 0, width: 600, height: 600))
    }

    @Test func thirdsWithGapLineUp() {
        // gap 15: area 870 wide, thirds 280 each with 15 between.
        #expect(frame(.leftThird, gap: 15) == CGRect(x: 15, y: 15, width: 280, height: 570))
        #expect(frame(.rightTwoThirds, gap: 15) == CGRect(x: 310, y: 15, width: 575, height: 570))
    }

    @Test func repeatingCyclesSizes() {
        func next(_ t: SnapTarget, from current: CGRect) -> SnapTarget {
            SnapGeometry.cycled(t, in: screen, current: current)
        }
        #expect(next(.leftHalf, from: window) == .leftHalf)
        #expect(next(.leftHalf, from: frame(.leftHalf)) == .leftTwoThirds)
        #expect(next(.leftHalf, from: frame(.leftTwoThirds)) == .leftThird)
        #expect(next(.leftHalf, from: frame(.leftThird)) == .leftHalf)
        #expect(next(.rightHalf, from: frame(.rightHalf)) == .rightTwoThirds)
        #expect(next(.maximize, from: frame(.maximize)) == .centerThird)
        #expect(next(.maximize, from: frame(.centerThird)) == .maximize)
        // A left-side frame doesn't advance the right-side cycle.
        #expect(next(.rightHalf, from: frame(.leftHalf)) == .rightHalf)
        #expect(next(.topLeft, from: frame(.topLeft)) == .topLeft)
    }

    @Test func oversizedWindowKeepsTargetEdge() {
        let wide = CGSize(width: 400, height: 600)
        #expect(SnapGeometry.anchored(wide, to: frame(.leftThird), in: screen) == CGRect(x: 0, y: 0, width: 400, height: 600))
        #expect(SnapGeometry.anchored(wide, to: frame(.rightThird), in: screen) == CGRect(x: 500, y: 0, width: 400, height: 600))
        #expect(SnapGeometry.anchored(wide, to: frame(.centerThird), in: screen) == CGRect(x: 250, y: 0, width: 400, height: 600))
    }

    @Test func undersizedWindowCentresOnFill() {
        let small = CGSize(width: 500, height: 400)
        #expect(SnapGeometry.anchored(small, to: frame(.maximize), in: screen) == CGRect(x: 200, y: 100, width: 500, height: 400))
        // Bottom-right quarter that's too tall stays on screen, against the bottom edge.
        let tall = CGSize(width: 450, height: 450)
        #expect(SnapGeometry.anchored(tall, to: frame(.bottomRight), in: screen) == CGRect(x: 450, y: 150, width: 450, height: 450))
    }
}
