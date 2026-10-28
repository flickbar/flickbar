/// User-facing gesture groups, each of which can be turned off in Settings.
public enum GestureKind: String, CaseIterable, Sendable {
    case halves, fill, quarters, restoreOrMinimize, center, fullScreen, close, moveToDisplay
}

public extension WindowAction {
    var kind: GestureKind {
        switch self {
        case .snap(.leftHalf), .snap(.rightHalf), .snap(.leftTwoThirds), .snap(.rightTwoThirds),
             .snap(.leftThird), .snap(.rightThird): .halves
        case .snap(.maximize), .snap(.centerThird): .fill
        case .snap(.topLeft), .snap(.topRight), .snap(.bottomLeft), .snap(.bottomRight): .quarters
        case .snap(.center): .center
        case .minimize: .restoreOrMinimize
        case .toggleFullscreen: .fullScreen
        case .close: .close
        case .moveToDisplay: .moveToDisplay
        }
    }
}
