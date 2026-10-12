import AppKit
#if canImport(DisposeCore)
import DisposeCore
#endif

/// Keeps the real windows in sync with the `Strip` model: reacts to windows
/// appearing/disappearing/focusing, runs commands, and applies frames.
final class StripManager {
    var onStateChange: (() -> Void)?
    private(set) var isPaused = false
    var windowCount: Int { strip.columns.count }

    private var strip = Strip<AXWindow>()
    private let tracker = WindowTracker()
    /// Where each window is (or is heading this frame), as last sent.
    private var applied: [AXWindow: CGRect] = [:]
    private var lastFocusRequest: (AXWindow, CFTimeInterval)?

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
        Log.write("arranging \(windows.count) windows: \(windows.map { $0.0.description })")
        strip = fresh
        stopAnimation()
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
    /// lost when Dispose pauses or quits.
    func releaseWindows() {
        stopAnimation()
        let viewport = Screen.viewport()
        for placement in strip.frames(in: viewport) where !placement.isOnScreen {
            let size = placement.frame.size
            mover.setFrame(placement.id, CGRect(
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
        guard let window = strip.focusedID else { return }
        lastFocusRequest = (window, CACurrentMediaTime())
        mover.focus(window)
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
            // Our own focus commands echo back here (often twice); skip those.
            guard strip.focusedID != window else { return }
            // Focus is applied asynchronously, so when keys are pressed fast a
            // late echo from an earlier request must not pull focus back.
            if let (requested, time) = lastFocusRequest,
               requested != window, CACurrentMediaTime() - time < 0.5 { return }
            strip.focus(window)
            layout()
        } else {
            windowAppeared(window)
        }
    }

    // MARK: Layout

    private func layout(animated: Bool = true) {
        guard !isPaused else { return }
        let viewport = Screen.viewport()
        strip.revealFocused(viewportWidth: viewport.width)
        for placement in strip.frames(in: viewport) {
            let window = placement.id
            var target = placement.frame
            if !placement.isOnScreen {
                // macOS won't reliably keep a window fully off-screen, so park
                // hidden columns just past the nearest edge, a sliver visible.
                target.origin.x = target.maxX <= viewport.minX
                    ? viewport.minX - target.width + 1
                    : viewport.maxX - 1
            }
            let current = applied[window] ?? window.frame ?? target
            if let motion = motions[window], motion.target == target.origin, current.size == target.size {
                continue  // already heading there
            }
            guard current != target || motions[window] != nil else { continue }

            // Off-screen to off-screen moves aren't worth animating.
            let visible = placement.isOnScreen || current.intersects(viewport)
            guard animated, visible else {
                motions[window] = nil
                mover.setFrame(window, target)
                applied[window] = target
                continue
            }
            // Resize once up front; animating size makes apps re-layout every frame.
            if current.size != target.size { mover.setSize(window, target.size) }
            // Keep any existing velocity so retargeting mid-flight stays fluid.
            var motion = motions[window] ?? Motion(position: current.origin)
            motion.target = target.origin
            motion.size = target.size
            motions[window] = motion
            applied[window] = CGRect(origin: motion.position, size: target.size)
        }
        motions = motions.filter { strip.contains($0.key) }
        startTimerIfNeeded()
    }

    // MARK: Animation

    /// A window sliding towards its target on a critically damped spring.
    private struct Motion {
        var position: CGPoint
        var velocity = CGVector.zero
        var target = CGPoint.zero
        var size = CGSize.zero
        /// Last position actually sent, to skip redundant moves.
        var sent: CGPoint?
    }

    /// Spring stiffness: higher is snappier. ~26 settles in about 0.25 s.
    private static let omega: CGFloat = 26
    private let mover = WindowMover()
    private var motions: [AXWindow: Motion] = [:]
    private var timer: Timer?
    private var lastTick: CFTimeInterval = 0

    private func startTimerIfNeeded() {
        guard timer == nil, !motions.isEmpty else { return }
        lastTick = CACurrentMediaTime()
        let timer = Timer(timeInterval: 1.0 / 120, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func tick() {
        let now = CACurrentMediaTime()
        // Clamp the step so a stalled frame can't make the spring jump.
        let dt = CGFloat(min(now - lastTick, 1.0 / 30))
        lastTick = now
        let w = Self.omega

        for (window, var m) in motions {
            let dx = m.target.x - m.position.x, dy = m.target.y - m.position.y
            m.velocity.dx += (w * w * dx - 2 * w * m.velocity.dx) * dt
            m.velocity.dy += (w * w * dy - 2 * w * m.velocity.dy) * dt
            m.position.x += m.velocity.dx * dt
            m.position.y += m.velocity.dy * dt

            let settled = abs(dx) < 0.5 && abs(dy) < 0.5
                && abs(m.velocity.dx) < 20 && abs(m.velocity.dy) < 20
            if settled {
                motions[window] = nil
                let final = CGRect(origin: m.target, size: m.size)
                mover.setFrame(window, final)
                applied[window] = final
                continue
            }
            let rounded = CGPoint(x: m.position.x.rounded(), y: m.position.y.rounded())
            if rounded != m.sent {
                mover.setPosition(window, rounded)
                m.sent = rounded
            }
            motions[window] = m
            applied[window] = CGRect(origin: m.position, size: m.size)
        }
        if motions.isEmpty { stopAnimation() }
    }

    private func stopAnimation() {
        timer?.invalidate()
        timer = nil
        motions.removeAll()
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
