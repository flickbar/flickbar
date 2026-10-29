import CoreGraphics

/// Hold-to-grid: a cursor over a 3×3 grid of layouts that finger movement steps through.
/// Columns are the screen's thirds; rows are the top half, the full height and the bottom half.
public struct GridCursor: Equatable, Sendable {
    public static let size = 3
    /// Points of finger travel per cell.
    public var step: CGFloat = 70

    public private(set) var column: Int
    public private(set) var row = 1
    private var travel = CGVector.zero

    /// Starts on the full-height third under `x`.
    public init(x: CGFloat, in visible: CGRect) {
        column = Self.clamp(Int((x - visible.minX) / visible.width * CGFloat(Self.size)))
    }

    /// `dx`/`dy` as finger movement (+x right, +y down). Returns true when the cell changed.
    @discardableResult
    public mutating func move(dx: CGFloat, dy: CGFloat) -> Bool {
        let before = (column, row)
        travel.dx += dx
        travel.dy += dy
        column = Self.step(column, &travel.dx, by: step)
        row = Self.step(row, &travel.dy, by: step)
        return before != (column, row)
    }

    public func frame(in visible: CGRect, gap: CGFloat = 0) -> CGRect {
        Self.frame(column: column, row: row, in: visible, gap: gap)
    }

    /// The six top and bottom cells, which together outline the whole grid.
    public static func outline(in visible: CGRect, gap: CGFloat = 0) -> [CGRect] {
        [0, 2].flatMap { row in (0..<size).map { frame(column: $0, row: row, in: visible, gap: gap) } }
    }

    static func frame(column: Int, row: Int, in visible: CGRect, gap: CGFloat) -> CGRect {
        let area = visible.insetBy(dx: gap, dy: gap)
        let w = (area.width - 2 * gap) / 3, halfH = (area.height - gap) / 2
        let x = area.minX + CGFloat(column) * (w + gap)
        return switch row {
        case 0: CGRect(x: x, y: area.minY, width: w, height: halfH).roundedToPoints
        case 2: CGRect(x: x, y: area.maxY - halfH, width: w, height: halfH).roundedToPoints
        default: CGRect(x: x, y: area.minY, width: w, height: area.height).roundedToPoints
        }
    }

    private static func clamp(_ i: Int) -> Int { max(0, min(size - 1, i)) }

    /// Moves `index` one cell per `step` of `travel`, keeping the remainder. Travel past an edge is dropped,
    /// so coming back from it moves right away.
    private static func step(_ index: Int, _ travel: inout CGFloat, by step: CGFloat) -> Int {
        var index = index
        while abs(travel) >= step {
            let next = clamp(index + (travel > 0 ? 1 : -1))
            if next == index { travel = 0; break }
            index = next
            travel -= travel > 0 ? step : -step
        }
        return index
    }
}
