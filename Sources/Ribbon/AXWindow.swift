import AppKit
import ApplicationServices

/// A window of another app, reached through the Accessibility API.
/// Equality and hashing follow the underlying window, so two AXUIElement
/// references to the same window compare equal.
final class AXWindow: Hashable, CustomStringConvertible {
    let element: AXUIElement
    let pid: pid_t

    init(_ element: AXUIElement) {
        self.element = element
        var pid: pid_t = 0
        AXUIElementGetPid(element, &pid)
        self.pid = pid
    }

    static func == (a: AXWindow, b: AXWindow) -> Bool { CFEqual(a.element, b.element) }
    func hash(into h: inout Hasher) { h.combine(CFHash(element)) }

    var description: String { "\(appName): \(title ?? "?")" }

    var title: String? { element.attribute(kAXTitleAttribute) }
    var appName: String { NSRunningApplication(processIdentifier: pid)?.localizedName ?? "pid \(pid)" }

    /// Whether this is an ordinary, resizable app window we should tile.
    /// Dialogs, sheets, panels, minimized and fullscreen windows are left alone.
    var isManageable: Bool {
        guard element.attribute(kAXRoleAttribute) as String? == kAXWindowRole,
              element.attribute(kAXSubroleAttribute) as String? == kAXStandardWindowSubrole,
              element.attribute(kAXMinimizedAttribute) as Bool? != true,
              element.attribute("AXFullScreen") as Bool? != true
        else { return false }
        return element.isSettable(kAXSizeAttribute) && element.isSettable(kAXPositionAttribute)
    }

    /// Frame in Accessibility coordinates: global, origin at the top-left
    /// of the primary display, y growing downwards.
    var frame: CGRect? {
        guard let p: CGPoint = element.axValue(kAXPositionAttribute, .cgPoint),
              let s: CGSize = element.axValue(kAXSizeAttribute, .cgSize)
        else { return nil }
        return CGRect(origin: p, size: s)
    }

    func setFrame(_ r: CGRect) {
        // Size, position, size: the first resize lets the move succeed when
        // the old size wouldn't fit at the new spot; the second applies the
        // final size if the app clamped the first one.
        element.setAXValue(kAXSizeAttribute, r.size, .cgSize)
        element.setAXValue(kAXPositionAttribute, r.origin, .cgPoint)
        element.setAXValue(kAXSizeAttribute, r.size, .cgSize)
    }

    func focus() {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetAttributeValue(app, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(element, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementPerformAction(element, kAXRaiseAction as CFString)
    }
}

extension AXUIElement {
    func attribute<T>(_ name: String) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(self, name as CFString, &value) == .success else { return nil }
        return value as? T
    }

    func element(_ name: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(self, name as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID()
        else { return nil }
        return (value as! AXUIElement)
    }

    func isSettable(_ name: String) -> Bool {
        var settable: DarwinBoolean = false
        return AXUIElementIsAttributeSettable(self, name as CFString, &settable) == .success && settable.boolValue
    }

    func axValue<T>(_ name: String, _ type: AXValueType) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(self, name as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXValueGetTypeID()
        else { return nil }
        let ptr = UnsafeMutablePointer<T>.allocate(capacity: 1)
        defer { ptr.deallocate() }
        return AXValueGetValue(value as! AXValue, type, ptr) ? ptr.pointee : nil
    }

    func setAXValue<T>(_ name: String, _ v: T, _ type: AXValueType) {
        guard let value = withUnsafePointer(to: v, { AXValueCreate(type, $0) }) else { return }
        AXUIElementSetAttributeValue(self, name as CFString, value)
    }
}
