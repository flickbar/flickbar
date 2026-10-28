import CoreGraphics

public enum SnapTarget: Equatable, Sendable {
    case leftHalf, rightHalf, maximize, center
    case topLeft, topRight, bottomLeft, bottomRight
}

public enum WindowAction: Equatable, Sendable {
    case snap(SnapTarget)
    case minimize, close, toggleFullscreen
}

public enum ActionMap {
    /// The action a finished gesture performs. Quarters accept either stroke order.
    public static func action(for strokes: [Stroke]) -> WindowAction? {
        switch strokes {
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
}
