import AppKit
#if canImport(RibbonCore)
import RibbonCore
#endif

/// Keeps the real windows in sync with the `Strip` model: reacts to windows
/// appearing/disappearing/focusing, runs commands, and applies frames.
final class StripManager {
    var onStateChange: (() -> Void)?
    private(set) var isPaused = false
    var windowCount: Int { strip.columns.count }

    private var strip = Strip<AXWindow>()
    private let tracker = WindowTracker()
    /// Last frame we set per window, so unchanged windows aren't touched.
    private var applied: [AXWindow: CGRect] = [:]

    func start() {
        tracker.start()
        tracker.onAppeared = { [weak self] in self?.windowAppeared($0) }
        tracker.onDisappeared = { [weak self] in self?.windowDisappeared($0) }
        tracker.onFocused = { [weak self] in self?.windowFocused($0) }
        tracker.onAppTerminated = { [weak self] pid in
            guard let self else { return }
            for id in strip.ids where id.pid == pid { windowDisappeared(id) }
        }
        rescan()
    }

    /// Rebuilds the strip from the windows on screen, left to right.
    func rescan() {
        let viewport = Screen.viewport()
        let windows = tracker.allWindows()
            .compactMap { w in w.frame.map { (w, $0) } }
            .sorted { $0.1.minX < $1.1.minX }
        var fresh = Strip<AXWindow>()
        for (window, frame) in windows {
            fresh.append(window, width: fresh.nearestPreset(forPixelWidth: frame.width, viewportWidth: viewport.width))
        }
        if let focused = tracker.focusedWindow() { fresh.focus(focused) }
        strip = fresh
        applied.removeAll()
        layout()
    }

    // MARK: Commands

    func focus(_ delta: Int) { command { $0.focusNeighbour(delta) }; focusWindow() }
    func focusEdge(last: Bool) { command { $0.focusEdge(last: last) }; focusWindow() }
    func focusIndex(_ i: Int) { command { $0.focusIndex(i) }; focusWindow() }
    func move(_ delta: Int) { command { $0.moveFocused(delta) } }
    func cycleWidth() { command { $0.cycleWidth() } }
    func toggleFullWidth() { command { $0.toggleFullWidth() } }
    func adjustWidth(_ delta: CGFloat) { command { $0.adjustWidth(by: delta) } }

    func centerFocused() {
        guard !isPaused else { return }
        strip.revealFocused(viewportWidth: Screen.viewport().width, center: true)
        layout()
    }

    func togglePaused() {
        isPaused.toggle()
        if isPaused { releaseWindows() } else { rescan() }
        onStateChange?()
    }

    /// Brings every parked (off-screen) window back into view so nothing is
    /// lost when Ribbon pauses or quits.
    func releaseWindows() {
        let viewport = Screen.viewport()
        for placement in strip.frames(in: viewport) where !placement.isOnScreen {
            let size = placement.frame.size
            placement.id.setFrame(CGRect(
                x: viewport.midX - size.width / 2,
                y: viewport.minY + strip.gap,
                width: size.width, height: size.height))
        }
        applied.removeAll()
    }

    private func command(_ change: (inout Strip<AXWindow>) -> Void) {
        guard !isPaused else { return }
        change(&strip)
        layout()
    }

    private func focusWindow() {
        guard !isPaused else { return }
        strip.focusedID?.focus()
    }

    // MARK: Tracker events

    private func windowAppeared(_ window: AXWindow) {
        guard !strip.contains(window) else { return }
        strip.insert(window, width: 0.5)
        layout()
        onStateChange?()
    }

    private func windowDisappeared(_ window: AXWindow) {
        guard strip.contains(window) else { return }
        strip.remove(window)
        applied[window] = nil
        layout()
        onStateChange?()
    }

    private func windowFocused(_ window: AXWindow) {
        if strip.contains(window) {
            strip.focus(window)
            layout()
        } else {
            windowAppeared(window)
        }
    }

    // MARK: Layout

    private func layout() {
        guard !isPaused else { return }
        let viewport = Screen.viewport()
        strip.revealFocused(viewportWidth: viewport.width)
        for placement in strip.frames(in: viewport) {
            var frame = placement.frame
            if !placement.isOnScreen {
                // macOS won't reliably keep a window fully off-screen, so park
                // hidden columns just past the nearest edge, a sliver visible.
                frame.origin.x = frame.maxX <= viewport.minX
                    ? viewport.minX - frame.width + 1
                    : viewport.maxX - 1
            }
            guard applied[placement.id] != frame else { continue }
            placement.id.setFrame(frame)
            applied[placement.id] = frame
        }
    }
}

enum Screen {
    /// Usable area of the primary display (minus menu bar and Dock) in
    /// Accessibility coordinates (origin top-left, y down).
    static func viewport() -> CGRect {
        guard let primary = NSScreen.screens.first else { return .zero }
        let visible = primary.visibleFrame
        return CGRect(x: visible.minX, y: primary.frame.maxY - visible.maxY,
                      width: visible.width, height: visible.height)
    }
}
