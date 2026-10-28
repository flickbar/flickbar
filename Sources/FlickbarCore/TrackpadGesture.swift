/// A gesture the user can assign an action to. The raw value is its key in the `gestureMap` preference.
public enum TrackpadGesture: String, CaseIterable, Sendable {
    case swipeLeft, swipeRight, swipeUp, swipeDown
    case swipeLeftUp, swipeRightUp, swipeLeftDown, swipeRightDown
    case doubleTap, pinchOut, pinchIn

    /// Two-stroke gestures accept either order.
    public init?(strokes: [Stroke]) {
        switch strokes {
        case [.left]: self = .swipeLeft
        case [.right]: self = .swipeRight
        case [.up]: self = .swipeUp
        case [.down]: self = .swipeDown
        case [.left, .up], [.up, .left]: self = .swipeLeftUp
        case [.right, .up], [.up, .right]: self = .swipeRightUp
        case [.left, .down], [.down, .left]: self = .swipeLeftDown
        case [.right, .down], [.down, .right]: self = .swipeRightDown
        case [.pinchIn]: self = .pinchIn
        case [.pinchOut]: self = .pinchOut
        default: return nil
        }
    }

    public var defaultAction: WindowAction {
        switch self {
        case .swipeLeft: .snap(.leftHalf)
        case .swipeRight: .snap(.rightHalf)
        case .swipeUp: .snap(.maximize)
        case .swipeDown: .minimize
        case .swipeLeftUp: .snap(.topLeft)
        case .swipeRightUp: .snap(.topRight)
        case .swipeLeftDown: .snap(.bottomLeft)
        case .swipeRightDown: .snap(.bottomRight)
        case .doubleTap: .snap(.center)
        case .pinchOut: .toggleFullscreen
        case .pinchIn: .close
        }
    }
}

public extension WindowAction {
    /// Actions a gesture can be set to, in menu order.
    static let assignable: [WindowAction] = SnapTarget.allCases.map(WindowAction.snap)
        + [.minimize, .toggleFullscreen, .close, .nextWindow, .hideApp, .quitApp]

    /// Stable name used in preferences.
    var id: String {
        switch self {
        case .snap(let target): target.rawValue
        case .minimize: "minimize"
        case .close: "close"
        case .toggleFullscreen: "toggleFullscreen"
        case .nextWindow: "nextWindow"
        case .hideApp: "hideApp"
        case .quitApp: "quitApp"
        case .moveToDisplay(let direction): "moveToDisplay.\(direction)"
        }
    }

    init?(id: String) {
        guard let action = Self.assignable.first(where: { $0.id == id }) else { return nil }
        self = action
    }
}
