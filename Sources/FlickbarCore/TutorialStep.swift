/// The gestures the first-run tutorial walks through, in order.
public enum TutorialStep: String, CaseIterable, Sendable {
    case leftHalf, rightHalf, fill, quarter, grid, minimize

    /// The id reported for a layout picked on the hold-to-grid, which isn't a `WindowAction`.
    public static let gridID = "grid"

    /// Whether running `actionID` (a `WindowAction.id`, or `gridID`) on the practice window completes this step.
    /// shortcut: matches the default gesture's action, so a remapped gesture ticks a different step; match on
    /// gestures instead if that confuses anyone.
    public func isDone(by actionID: String) -> Bool {
        switch self {
        case .leftHalf: actionID == SnapTarget.leftHalf.rawValue
        case .rightHalf: actionID == SnapTarget.rightHalf.rawValue
        case .fill: actionID == SnapTarget.maximize.rawValue
        case .quarter: [SnapTarget.topLeft, .topRight, .bottomLeft, .bottomRight].map(\.rawValue).contains(actionID)
        case .grid: actionID == Self.gridID
        case .minimize: actionID == WindowAction.minimize.id || actionID == WindowAction.restoreOrMinimize.id
        }
    }
}
