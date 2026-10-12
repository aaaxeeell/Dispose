import CoreGraphics

/// A column on the strip. For now each column holds exactly one window.
public struct Column<ID: Hashable> {
    public var id: ID
    /// Width as a fraction of the usable viewport width (0...1].
    public var width: CGFloat
    /// Width to go back to when leaving full-width mode.
    var restoreWidth: CGFloat?
}

/// A placed column: where its window should go, in the same coordinate
/// space as the viewport passed to `frames(in:)`.
public struct Placement<ID: Hashable> {
    public var id: ID
    public var frame: CGRect
    /// False when the column lies entirely outside the viewport.
    public var isOnScreen: Bool
}

/// An endless horizontal strip of columns, scrolled so the focused column
/// is always visible. Pure value type: no AppKit, no side effects.
public struct Strip<ID: Hashable> {
    public static var presetWidths: [CGFloat] { [1.0 / 3, 0.5, 2.0 / 3] }
    public static var minWidth: CGFloat { 0.15 }
    public static var widthStep: CGFloat { 0.05 }

    public var gap: CGFloat
    public private(set) var columns: [Column<ID>] = []
    public private(set) var focusedIndex: Int?
    /// Strip x-coordinate shown at the left edge of the usable viewport.
    public private(set) var scroll: CGFloat = 0

    public init(gap: CGFloat = 10) {
        self.gap = gap
    }

    public var focusedID: ID? { focusedIndex.map { columns[$0].id } }
    public var ids: [ID] { columns.map(\.id) }

    public func index(of id: ID) -> Int? { columns.firstIndex { $0.id == id } }
    public func contains(_ id: ID) -> Bool { index(of: id) != nil }

    // MARK: Membership

    /// Adds a window to the right of the focused column and focuses it.
    public mutating func insert(_ id: ID, width: CGFloat = 0.5) {
        guard !contains(id) else { return }
        let at = focusedIndex.map { $0 + 1 } ?? columns.count
        columns.insert(Column(id: id, width: width), at: at)
        focusedIndex = at
    }

    /// Adds a window at the end without changing focus.
    public mutating func append(_ id: ID, width: CGFloat = 0.5) {
        guard !contains(id) else { return }
        columns.append(Column(id: id, width: width))
        if focusedIndex == nil { focusedIndex = 0 }
    }

    public mutating func remove(_ id: ID) {
        guard let i = index(of: id) else { return }
        columns.remove(at: i)
        guard let f = focusedIndex, !columns.isEmpty else {
            focusedIndex = nil
            scroll = 0
            return
        }
        // Removing the focused column focuses its right neighbour (or the
        // new last column); removing one to its left shifts focus down.
        if i < f || f >= columns.count { focusedIndex = max(0, f - 1) }
    }

    // MARK: Focus and order

    public mutating func focus(_ id: ID) {
        if let i = index(of: id) { focusedIndex = i }
    }

    public mutating func focusNeighbour(_ delta: Int) {
        guard let f = focusedIndex else { return }
        focusedIndex = clampIndex(f + delta)
    }

    public mutating func focusEdge(last: Bool) {
        guard !columns.isEmpty else { return }
        focusedIndex = last ? columns.count - 1 : 0
    }

    public mutating func focusIndex(_ i: Int) {
        guard columns.indices.contains(i) else { return }
        focusedIndex = i
    }

    /// Swaps the focused column with its neighbour; focus follows it.
    public mutating func moveFocused(_ delta: Int) {
        guard let f = focusedIndex else { return }
        let to = clampIndex(f + delta)
        guard to != f else { return }
        columns.swapAt(f, to)
        focusedIndex = to
    }

    // MARK: Width

    public mutating func cycleWidth() {
        guard let f = focusedIndex else { return }
        let w = columns[f].width
        let presets = Self.presetWidths
        columns[f].width = presets.first { $0 > w + 0.01 } ?? presets[0]
        columns[f].restoreWidth = nil
    }

    public mutating func toggleFullWidth() {
        guard let f = focusedIndex else { return }
        if columns[f].width >= 0.999 {
            columns[f].width = columns[f].restoreWidth ?? 0.5
            columns[f].restoreWidth = nil
        } else {
            columns[f].restoreWidth = columns[f].width
            columns[f].width = 1
        }
    }

    public mutating func adjustWidth(by delta: CGFloat) {
        guard let f = focusedIndex else { return }
        columns[f].width = min(1, max(Self.minWidth, columns[f].width + delta))
        columns[f].restoreWidth = nil
    }

    /// Snaps a pixel width to the nearest preset (or full width).
    public func nearestPreset(forPixelWidth px: CGFloat, viewportWidth: CGFloat) -> CGFloat {
        let usable = viewportWidth - 2 * gap
        let fraction = (px + gap) / (usable + gap)
        return (Self.presetWidths + [1]).min { abs($0 - fraction) < abs($1 - fraction) }!
    }

    // MARK: Geometry

    /// Pixel width of a column. Fractions are defined so that e.g. two 0.5
    /// columns plus the gap between them fill the usable width exactly.
    public func pixelWidth(of column: Column<ID>, usable: CGFloat) -> CGFloat {
        (column.width * (usable + gap) - gap).rounded()
    }

    /// Strip x-offset of every column's left edge.
    func offsets(usable: CGFloat) -> [CGFloat] {
        var x: CGFloat = 0
        return columns.map { column in
            defer { x += pixelWidth(of: column, usable: usable) + gap }
            return x
        }
    }

    func totalWidth(usable: CGFloat) -> CGFloat {
        guard let last = columns.last, let x = offsets(usable: usable).last else { return 0 }
        return x + pixelWidth(of: last, usable: usable)
    }

    /// Scrolls the minimum amount needed to show the focused column fully,
    /// or centres it when `center` is true.
    public mutating func revealFocused(viewportWidth: CGFloat, center: Bool = false) {
        guard let f = focusedIndex else { return }
        let usable = viewportWidth - 2 * gap
        let x = offsets(usable: usable)[f]
        let w = pixelWidth(of: columns[f], usable: usable)
        if center {
            scroll = x + w / 2 - usable / 2
        } else if x < scroll {
            scroll = x
        } else if x + w > scroll + usable {
            scroll = x + w - usable
        }
        let maxScroll = max(0, totalWidth(usable: usable) - usable)
        scroll = min(max(scroll, 0), maxScroll)
    }

    /// Where every window should go for the current scroll position.
    public func frames(in viewport: CGRect) -> [Placement<ID>] {
        let usable = viewport.width - 2 * gap
        let height = viewport.height - 2 * gap
        return zip(columns, offsets(usable: usable)).map { column, x in
            let frame = CGRect(
                x: viewport.minX + gap + x - scroll,
                y: viewport.minY + gap,
                width: pixelWidth(of: column, usable: usable),
                height: height
            )
            let onScreen = frame.maxX > viewport.minX && frame.minX < viewport.maxX
            return Placement(id: column.id, frame: frame, isOnScreen: onScreen)
        }
    }

    private func clampIndex(_ i: Int) -> Int {
        min(max(i, 0), columns.count - 1)
    }
}
