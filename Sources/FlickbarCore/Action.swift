import CoreGraphics

public enum SnapTarget: Equatable, Sendable {
    case leftHalf, rightHalf, maximize, center
    case topLeft, topRight, bottomLeft, bottomRight
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
        let rect: CGRect = switch target {
        case .maximize: area
        case .leftHalf: CGRect(x: area.minX, y: area.minY, width: halfW, height: area.height)
        case .rightHalf: CGRect(x: rightX, y: area.minY, width: halfW, height: area.height)
        case .topLeft: CGRect(x: area.minX, y: area.minY, width: halfW, height: halfH)
        case .topRight: CGRect(x: rightX, y: area.minY, width: halfW, height: halfH)
        case .bottomLeft: CGRect(x: area.minX, y: bottomY, width: halfW, height: halfH)
        case .bottomRight: CGRect(x: rightX, y: bottomY, width: halfW, height: halfH)
        case .center:
            CGRect(x: area.midX - current.width / 2, y: area.midY - current.height / 2,
                   width: min(current.width, area.width), height: min(current.height, area.height))
        }
        return rect.integral
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
                      width: frame.width * sx, height: frame.height * sy).integral
    }
}
