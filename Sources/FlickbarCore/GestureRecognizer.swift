import CoreGraphics

public enum Stroke: Equatable, Sendable {
    case left, right, up, down, pinchIn, pinchOut
}

/// Turns a stream of two-finger scroll / magnify samples into a list of strokes.
/// Within one finger-down…finger-up sequence, strokes combine while they match a supported gesture.
/// When direction changes are enabled, an unsupported swipe sequence swaps its last stroke, or restarts from it.
/// Reversed pinches always cancel.
public struct GestureRecognizer: Sendable {
    /// Points of travel along one axis before a swipe stroke counts.
    public var swipeThreshold: CGFloat = 40
    /// Dominant axis must be this many times larger than the other axis.
    public var axisRatio: CGFloat = 1.8
    /// Cumulative magnification before a pinch stroke counts.
    public var pinchThreshold: CGFloat = 0.12
    /// Follow swipe direction changes; when off, unsupported sequences cancel instead.
    public var followsDirectionChanges = true

    public private(set) var strokes: [Stroke] = []
    private var travel = CGVector.zero
    private var zoom: CGFloat = 0

    public init() {}

    public mutating func reset() {
        strokes = []
        travel = .zero
        zoom = 0
    }

    /// `dx`/`dy` in screen terms: +x = fingers moved right, +y = fingers moved down.
    @discardableResult
    public mutating func addScroll(dx: CGFloat, dy: CGFloat) -> Stroke? {
        travel.dx += dx
        travel.dy += dy
        let ax = abs(travel.dx), ay = abs(travel.dy)
        let stroke: Stroke
        if ax >= swipeThreshold, ax >= ay * axisRatio {
            stroke = travel.dx > 0 ? .right : .left
        } else if ay >= swipeThreshold, ay >= ax * axisRatio {
            stroke = travel.dy > 0 ? .down : .up
        } else {
            return nil
        }
        return commit(stroke)
    }

    @discardableResult
    public mutating func addMagnification(_ m: CGFloat) -> Stroke? {
        zoom += m
        guard abs(zoom) >= pinchThreshold else { return nil }
        return commit(zoom > 0 ? .pinchOut : .pinchIn)
    }

    private mutating func commit(_ stroke: Stroke) -> Stroke? {
        travel = .zero
        zoom = 0
        // Continuing in the same direction extends the current stroke instead of repeating it.
        if strokes.last == stroke { return nil }
        let next = strokes + [stroke]
        let onlySwipes = next.allSatisfy { $0 != .pinchIn && $0 != .pinchOut }
        if followsDirectionChanges && onlySwipes && TrackpadGesture(strokes: next) == nil {
            // Swap the latest stroke first ([right, up] + down → [right, down]); otherwise start over.
            let swapped = Array(strokes.dropLast()) + [stroke]
            strokes = TrackpadGesture(strokes: swapped) != nil ? swapped : [stroke]
        } else {
            strokes = next
        }
        return stroke
    }
}
