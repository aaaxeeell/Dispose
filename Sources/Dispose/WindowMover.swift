import ApplicationServices
import Foundation
import QuartzCore

/// Applies window moves off the main thread, one serial queue per app.
///
/// Every Accessibility call is a synchronous round trip to the target app,
/// and some apps (Electron, busy browsers) take many milliseconds to answer.
/// Doing that on the main thread stalls animation and hotkeys. Here each app
/// gets its own queue, and requests are coalesced: if an app is still busy,
/// only the newest position/size is applied when it's free again — a slow
/// app drops frames instead of building a backlog.
final class WindowMover {
    private struct Pending {
        var position: CGPoint?
        var size: CGSize?
        var focus = false
    }

    private let lock = NSLock()
    private var pending: [AXWindow: Pending] = [:]
    private var busy: Set<pid_t> = []
    private var queues: [pid_t: DispatchQueue] = [:]

    func setPosition(_ window: AXWindow, _ position: CGPoint) {
        enqueue(window) { $0.position = position }
    }

    func setFrame(_ window: AXWindow, _ frame: CGRect) {
        enqueue(window) { $0.position = frame.origin; $0.size = frame.size }
    }

    func setSize(_ window: AXWindow, _ size: CGSize) {
        enqueue(window) { $0.size = size }
    }

    func focus(_ window: AXWindow) {
        enqueue(window) { $0.focus = true }
    }

    /// Drops queued updates and waits for in-flight ones to finish, so the
    /// caller can then move windows directly without a stale update landing
    /// afterwards.
    func cancelAndWait() {
        lock.lock()
        pending.removeAll()
        let all = Array(queues.values)
        lock.unlock()
        for queue in all { queue.sync {} }
    }

    private func enqueue(_ window: AXWindow, _ change: (inout Pending) -> Void) {
        let pid = window.pid
        lock.lock()
        change(&pending[window, default: Pending()])
        let idle = busy.insert(pid).inserted
        let queue = queues[pid] ?? DispatchQueue(label: "dispose.mover.\(pid)", qos: .userInteractive)
        queues[pid] = queue
        lock.unlock()
        if idle { queue.async { self.drain(pid) } }
    }

    private func drain(_ pid: pid_t) {
        // With AXEnhancedUserInterface on (some apps enable it for assistive
        // tools), every move is animated by the app and slow. Turn it off for
        // this burst of moves and restore it once the queue is idle.
        let app = AXUIElementCreateApplication(pid)
        let enhanced = app.attribute("AXEnhancedUserInterface") as Bool? == true
        if enhanced { AXUIElementSetAttributeValue(app, "AXEnhancedUserInterface" as CFString, kCFBooleanFalse) }
        defer { if enhanced { AXUIElementSetAttributeValue(app, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue) } }

        while true {
            lock.lock()
            let batch = pending.filter { $0.key.pid == pid }
            for window in batch.keys { pending[window] = nil }
            if batch.isEmpty { busy.remove(pid) }
            lock.unlock()
            guard !batch.isEmpty else { return }

            for (window, op) in batch {
                let start = CACurrentMediaTime()
                switch (op.position, op.size) {
                case let (p?, s?): window.setFrame(CGRect(origin: p, size: s))
                case let (p?, nil): window.setPosition(p)
                case let (nil, s?): window.setSize(s)
                case (nil, nil): break
                }
                if op.focus { window.focus() }
                let ms = (CACurrentMediaTime() - start) * 1000
                if ms > 25 { Log.write(String(format: "slow app: %.0f ms to update %@", ms, window.appName)) }
            }
        }
    }
}
