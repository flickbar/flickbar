import CoreGraphics

public enum SnapTarget: Equatable, Sendable {
    case leftHalf, rightHalf, maximize, center
    case topLeft, topRight, bottomLeft, bottomRight
    case leftThird, centerThird, rightThird, leftTwoThirds, rightTwoThirds
}

public enum WindowAction: Equatable, Sendable {
    case snap(SnapTarget)
    case minimize, close, toggleFullscreen
    case moveToDisplay(Stroke)
}

public enum ActionMap {
    /// The action a finished gesture performs. Quarters accept either stroke order.
    /// With ⌘ held, a single swipe moves the window to the neighbouring display instead.
    public static func action(for strokes: [Stroke], command: Bool = false) -> WindowAction? {
        if command {
            guard strokes.count == 1, let s = strokes.first, s != .pinchIn, s != .pinchOut else { return nil }
            return .moveToDisplay(s)
        }
        return switch strokes {
        case [.left]: .snap(.leftHalf)
        case [.right]: .snap(.rightHalf)
        case [.up]: .snap(.maximize)
        case [.down]: .minimize
        case [.left, .up], [.up, .left]: .snap(.topLeft)
        case [.right, .up], [.up, .right]: .snap(.topRight)
        case [.left, .down], [.down, .left]: .snap(.bottomLeft)
        case [.right, .down], [.down, .right]: .snap(.bottomRight)
        case [.pinchIn]: .close
        case [.pinchOut]: .toggleFullscreen
        default: nil
        }
    }
}

public enum SnapGeometry {
    /// Target frame inside `visible` (top-left origin, as the Accessibility API uses).
    /// `current` is only used for `.center`, which keeps the window's size.
    public static func frame(for target: SnapTarget, in visible: CGRect, current: CGRect, gap: CGFloat = 0) -> CGRect {
        let area = visible.insetBy(dx: gap, dy: gap)
        let halfW = (area.width - gap) / 2, halfH = (area.height - gap) / 2
        let rightX = area.minX + halfW + gap, bottomY = area.minY + halfH + gap
        let thirdW = (area.width - 2 * gap) / 3, twoThirdsW = thirdW * 2 + gap
        let rect: CGRect = switch target {
        case .maximize: area
        case .leftHalf: CGRect(x: area.minX, y: area.minY, width: halfW, height: area.height)
        case .rightHalf: CGRect(x: rightX, y: area.minY, width: halfW, height: area.height)
        case .topLeft: CGRect(x: area.minX, y: area.minY, width: halfW, height: halfH)
        case .topRight: CGRect(x: rightX, y: area.minY, width: halfW, height: halfH)
        case .bottomLeft: CGRect(x: area.minX, y: bottomY, width: halfW, height: halfH)
        case .bottomRight: CGRect(x: rightX, y: bottomY, width: halfW, height: halfH)
        case .leftThird: CGRect(x: area.minX, y: area.minY, width: thirdW, height: area.height)
        case .centerThird: CGRect(x: area.minX + thirdW + gap, y: area.minY, width: thirdW, height: area.height)
        case .rightThird: CGRect(x: area.maxX - thirdW, y: area.minY, width: thirdW, height: area.height)
        case .leftTwoThirds: CGRect(x: area.minX, y: area.minY, width: twoThirdsW, height: area.height)
        case .rightTwoThirds: CGRect(x: area.maxX - twoThirdsW, y: area.minY, width: twoThirdsW, height: area.height)
        case .center:
            CGRect(x: area.midX - current.width / 2, y: area.midY - current.height / 2,
                   width: min(current.width, area.width), height: min(current.height, area.height))
        }
        return rect.roundedToPoints
    }

    /// Repeating a snap cycles through sizes: half → ⅔ → ⅓ on each side, and fill → centre third.
    static let cycles: [[SnapTarget]] = [
        [.leftHalf, .leftTwoThirds, .leftThird],
        [.rightHalf, .rightTwoThirds, .rightThird],
        [.maximize, .centerThird],
    ]

    /// The target a gesture for `target` should use, given that the window may already sit on a step of its cycle.
    public static func cycled(_ target: SnapTarget, in visible: CGRect, current: CGRect, gap: CGFloat = 0) -> SnapTarget {
        guard let cycle = cycles.first(where: { $0.first == target }),
              let i = cycle.firstIndex(where: { frame(for: $0, in: visible, current: current, gap: gap).isClose(to: current) })
        else { return target }
        return cycle[(i + 1) % cycle.count]
    }

    /// Where a window of `size` goes when the app wouldn't take `target`'s size (minimum/maximum sizes):
    /// kept against the same screen edge as `target`, or centred on it, and inside `visible` where it fits.
    public static func anchored(_ size: CGSize, to target: CGRect, in visible: CGRect) -> CGRect {
        func place(_ lo: CGFloat, _ hi: CGFloat, _ length: CGFloat, _ mid: CGFloat, _ screenLo: CGFloat, _ screenHi: CGFloat) -> CGFloat {
            let screenMid = (screenLo + screenHi) / 2
            let start = mid < screenMid - 1 ? lo : mid > screenMid + 1 ? hi - length : mid - length / 2
            return max(screenLo, min(start, screenHi - length))
        }
        return CGRect(x: place(target.minX, target.maxX, size.width, target.midX, visible.minX, visible.maxX),
                      y: place(target.minY, target.maxY, size.height, target.midY, visible.minY, visible.maxY),
                      width: size.width, height: size.height).roundedToPoints
    }

    /// The display next to `current` in `direction` (nearest centre on that side), or nil if there is none.
    public static func neighbor(of current: CGRect, in screens: [CGRect], toward direction: Stroke) -> CGRect? {
        let candidates = screens.filter { s in
            switch direction {
            case .left: s.midX < current.minX
            case .right: s.midX > current.maxX
            case .up: s.midY < current.minY
            case .down: s.midY > current.maxY
            case .pinchIn, .pinchOut: false
            }
        }
        let distance = { (s: CGRect) in hypot(s.midX - current.midX, s.midY - current.midY) }
        return candidates.min { distance($0) < distance($1) }
    }

    /// `frame` moved from one visible area to another, keeping its relative position and size.
    public static func relocate(_ frame: CGRect, from source: CGRect, to destination: CGRect) -> CGRect {
        let sx = destination.width / source.width, sy = destination.height / source.height
        return CGRect(x: destination.minX + (frame.minX - source.minX) * sx,
                      y: destination.minY + (frame.minY - source.minY) * sy,
                      width: frame.width * sx, height: frame.height * sy).roundedToPoints
    }
}

public extension CGRect {
    /// Apps may nudge a frame after a move (e.g. terminals round to character cells), so compare loosely.
    func isClose(to other: CGRect, tolerance: CGFloat = 8) -> Bool {
        abs(minX - other.minX) <= tolerance && abs(minY - other.minY) <= tolerance
            && abs(width - other.width) <= tolerance && abs(height - other.height) <= tolerance
    }
}

private extension CGRect {
    /// Nearest whole points. Unlike `integral` (which grows outward) this doesn't inflate frames on round trips.
    var roundedToPoints: CGRect {
        CGRect(x: minX.rounded(), y: minY.rounded(), width: width.rounded(), height: height.rounded())
    }
}
