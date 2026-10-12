import AppKit
import ApplicationServices

/// Discovers app windows and reports when they appear, disappear or gain
/// focus, using one AXObserver per running app.
final class WindowTracker {
    var onAppeared: ((AXWindow) -> Void)?
    var onDisappeared: ((AXWindow) -> Void)?
    var onFocused: ((AXWindow) -> Void)?
    var onAppTerminated: ((pid_t) -> Void)?

    private var observers: [pid_t: AXObserver] = [:]
    private let ownPID = ProcessInfo.processInfo.processIdentifier

    func start() {
        for app in NSWorkspace.shared.runningApplications {
            observe(app, announceWindows: false)
        }
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { [weak self] n in
            guard let app = n.runningApp else { return }
            self?.observe(app, announceWindows: true)
        }
        nc.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] n in
            guard let pid = n.runningApp?.processIdentifier else { return }
            if let observer = self?.observers.removeValue(forKey: pid) {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
            }
            self?.onAppTerminated?(pid)
        }
        // Switching apps (Cmd-Tab, Dock click) doesn't fire the per-app
        // focused-window notification, so read the new app's window here.
        nc.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] n in
            guard let pid = n.runningApp?.processIdentifier, let window = self?.focusedWindow(of: pid) else { return }
            self?.onFocused?(window)
        }
    }

    /// Every manageable window of every regular app.
    func allWindows() -> [AXWindow] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.processIdentifier != ownPID }
            .flatMap { windows(of: $0.processIdentifier) }
    }

    func focusedWindow() -> AXWindow? {
        NSWorkspace.shared.frontmostApplication.flatMap { focusedWindow(of: $0.processIdentifier) }
    }

    private func focusedWindow(of pid: pid_t) -> AXWindow? {
        AXUIElementCreateApplication(pid).element(kAXFocusedWindowAttribute)
            .map(AXWindow.init)
            .flatMap { $0.isManageable ? $0 : nil }
    }

    private func windows(of pid: pid_t) -> [AXWindow] {
        let app = AXUIElementCreateApplication(pid)
        let elements: [AXUIElement] = app.attribute(kAXWindowsAttribute) ?? []
        return elements.map(AXWindow.init).filter(\.isManageable)
    }

    private func observe(_ app: NSRunningApplication, announceWindows: Bool, attempt: Int = 0) {
        let pid = app.processIdentifier
        guard app.activationPolicy == .regular, pid != ownPID, observers[pid] == nil, !app.isTerminated else { return }

        var created: AXObserver?
        guard AXObserverCreate(pid, axCallback, &created) == .success, let observer = created else { return }
        let appElement = AXUIElementCreateApplication(pid)
        let notifications = [
            kAXWindowCreatedNotification,
            kAXFocusedWindowChangedNotification,
            kAXWindowMiniaturizedNotification,
            kAXWindowDeminiaturizedNotification,
        ]
        let registered = notifications.filter {
            AXObserverAddNotification(observer, appElement, $0 as CFString, refcon) == .success
        }
        guard !registered.isEmpty else {
            // A freshly launched app often isn't ready for AX yet; retry.
            if attempt < 10 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.observe(app, announceWindows: announceWindows, attempt: attempt + 1)
                }
            }
            return
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        observers[pid] = observer

        for window in windows(of: pid) {
            watchDestruction(of: window)
            if announceWindows { onAppeared?(window) }
        }
    }

    private func watchDestruction(of window: AXWindow) {
        guard let observer = observers[window.pid] else { return }
        AXObserverAddNotification(observer, window.element, kAXUIElementDestroyedNotification as CFString, refcon)
    }

    private var refcon: UnsafeMutableRawPointer { Unmanaged.passUnretained(self).toOpaque() }

    fileprivate func handle(_ element: AXUIElement, _ notification: String) {
        switch notification {
        case kAXWindowCreatedNotification, kAXWindowDeminiaturizedNotification:
            // New windows often get their subrole and size a moment later.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                let window = AXWindow(element)
                guard window.isManageable else { return }
                self?.watchDestruction(of: window)
                self?.onAppeared?(window)
            }
        case kAXUIElementDestroyedNotification, kAXWindowMiniaturizedNotification:
            onDisappeared?(AXWindow(element))
        case kAXFocusedWindowChangedNotification:
            let window = AXWindow(element)
            if window.isManageable { onFocused?(window) }
        default:
            break
        }
    }
}

private func axCallback(_: AXObserver, element: AXUIElement, notification: CFString, refcon: UnsafeMutableRawPointer?) {
    guard let refcon else { return }
    Unmanaged<WindowTracker>.fromOpaque(refcon).takeUnretainedValue().handle(element, notification as String)
}

private extension Notification {
    var runningApp: NSRunningApplication? {
        userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
    }
}
