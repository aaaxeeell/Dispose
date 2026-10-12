import AppKit
import Carbon

struct Shortcut {
    let keys: String
    let name: String
    let keyCode: Int
    let modifiers: Int
    let action: (StripManager) -> Void
}

private let ctrlOpt = controlKey | optionKey

/// The default bindings. Key codes are physical positions (US layout labels).
let shortcuts: [Shortcut] = {
    var list = [
        Shortcut(keys: "⌃⌥←  or  ⌃⌥H", name: "Focus left", keyCode: kVK_LeftArrow, modifiers: ctrlOpt) { $0.focus(-1) },
        Shortcut(keys: "", name: "", keyCode: kVK_ANSI_H, modifiers: ctrlOpt) { $0.focus(-1) },
        Shortcut(keys: "⌃⌥→  or  ⌃⌥L", name: "Focus right", keyCode: kVK_RightArrow, modifiers: ctrlOpt) { $0.focus(1) },
        Shortcut(keys: "", name: "", keyCode: kVK_ANSI_L, modifiers: ctrlOpt) { $0.focus(1) },
        Shortcut(keys: "⌃⌥⌘←", name: "Focus first", keyCode: kVK_LeftArrow, modifiers: ctrlOpt | cmdKey) { $0.focusEdge(last: false) },
        Shortcut(keys: "⌃⌥⌘→", name: "Focus last", keyCode: kVK_RightArrow, modifiers: ctrlOpt | cmdKey) { $0.focusEdge(last: true) },
        Shortcut(keys: "⌃⌥⇧←  or  ⌃⌥⇧H", name: "Move window left", keyCode: kVK_LeftArrow, modifiers: ctrlOpt | shiftKey) { $0.move(-1) },
        Shortcut(keys: "", name: "", keyCode: kVK_ANSI_H, modifiers: ctrlOpt | shiftKey) { $0.move(-1) },
        Shortcut(keys: "⌃⌥⇧→  or  ⌃⌥⇧L", name: "Move window right", keyCode: kVK_RightArrow, modifiers: ctrlOpt | shiftKey) { $0.move(1) },
        Shortcut(keys: "", name: "", keyCode: kVK_ANSI_L, modifiers: ctrlOpt | shiftKey) { $0.move(1) },
        Shortcut(keys: "⌃⌥R", name: "Cycle width ⅓ · ½ · ⅔", keyCode: kVK_ANSI_R, modifiers: ctrlOpt) { $0.cycleWidth() },
        Shortcut(keys: "⌃⌥F", name: "Toggle full width", keyCode: kVK_ANSI_F, modifiers: ctrlOpt) { $0.toggleFullWidth() },
        Shortcut(keys: "⌃⌥C", name: "Center window", keyCode: kVK_ANSI_C, modifiers: ctrlOpt) { $0.centerFocused() },
        Shortcut(keys: "⌃⌥=", name: "Wider", keyCode: kVK_ANSI_Equal, modifiers: ctrlOpt) { $0.adjustWidth(0.05) },
        Shortcut(keys: "⌃⌥-", name: "Narrower", keyCode: kVK_ANSI_Minus, modifiers: ctrlOpt) { $0.adjustWidth(-0.05) },
        Shortcut(keys: "⌃⌥P", name: "Pause / resume", keyCode: kVK_ANSI_P, modifiers: ctrlOpt) { $0.togglePaused() },
    ]
    let digits = [kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5,
                  kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9]
    for (i, key) in digits.enumerated() {
        list.append(Shortcut(keys: i == 0 ? "⌃⌥1 … 9" : "", name: i == 0 ? "Focus window 1–9" : "",
                             keyCode: key, modifiers: ctrlOpt) { $0.focusIndex(i) })
    }
    return list
}()

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let manager = StripManager()
    private let hotKeys = HotKeyCenter()
    private var statusItem: NSStatusItem!
    private var started = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "rectangle.split.3x1", accessibilityDescription: "Ribbon")
        manager.onStateChange = { [weak self] in self?.rebuildMenu() }
        rebuildMenu()

        let prompt = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        if AXIsProcessTrustedWithOptions(prompt) { startManaging() } else { waitForAccessibility() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if started { manager.releaseWindows() }
    }

    private func waitForAccessibility() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            if AXIsProcessTrusted() { self?.startManaging() } else { self?.waitForAccessibility() }
        }
    }

    private func startManaging() {
        guard !started else { return }
        started = true
        for shortcut in shortcuts {
            hotKeys.register(shortcut.keyCode, shortcut.modifiers) { [weak self] in
                guard let self else { return }
                shortcut.action(manager)
            }
        }
        manager.start()
        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        let status: String
        if !started { status = "Waiting for Accessibility permission…" }
        else if manager.isPaused { status = "Paused" }
        else { status = "Arranging \(manager.windowCount) window\(manager.windowCount == 1 ? "" : "s")" }
        menu.addItem(withTitle: status, action: nil, keyEquivalent: "").isEnabled = false

        if !started {
            menu.addItem(item("Open Accessibility Settings…", #selector(openAccessibilitySettings)))
        } else {
            menu.addItem(item(manager.isPaused ? "Resume" : "Pause", #selector(togglePaused)))
            menu.addItem(item("Re-arrange All Windows", #selector(rescan)))
        }

        menu.addItem(.separator())
        let help = NSMenuItem(title: "Shortcuts", action: nil, keyEquivalent: "")
        let helpMenu = NSMenu()
        for shortcut in shortcuts where !shortcut.name.isEmpty {
            helpMenu.addItem(withTitle: "\(shortcut.name)\t\(shortcut.keys)", action: nil, keyEquivalent: "").isEnabled = false
        }
        help.submenu = helpMenu
        menu.addItem(help)
        menu.addItem(.separator())
        menu.addItem(item("Quit Ribbon", #selector(quit), key: "q"))
        statusItem.menu = menu
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func togglePaused() { manager.togglePaused() }
    @objc private func rescan() { manager.rescan(); rebuildMenu() }
    @objc private func quit() { NSApp.terminate(nil) }
    @objc private func openAccessibilitySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
}
