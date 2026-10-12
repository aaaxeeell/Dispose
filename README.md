# Ribbon

A scrolling window manager for macOS. Every window becomes a column on one
endless horizontal strip. Windows never overlap, opening a new one never
shrinks the others, and the strip scrolls to keep the focused window in view.

> Status: early prototype (v0.1). Single display, keyboard-driven.

## What works

- Windows laid out side by side as columns, sized ⅓ · ½ · ⅔ or full width
- New windows open to the right of the focused one
- Strip scrolls just enough to keep the focused window fully visible
- Focus changes from the mouse, Cmd-Tab or the Dock are followed
- Dialogs, sheets, minimized and fullscreen windows are left alone
- Menu-bar icon with pause/resume; windows are brought back on screen when
  pausing or quitting

## Shortcuts

| Keys | Action |
| --- | --- |
| ⌃⌥← / ⌃⌥H | Focus left |
| ⌃⌥→ / ⌃⌥L | Focus right |
| ⌃⌥⌘← / ⌃⌥⌘→ | Focus first / last |
| ⌃⌥1 … 9 | Focus window 1–9 |
| ⌃⌥⇧← / ⌃⌥⇧H | Move window left |
| ⌃⌥⇧→ / ⌃⌥⇧L | Move window right |
| ⌃⌥R | Cycle width ⅓ · ½ · ⅔ |
| ⌃⌥F | Toggle full width |
| ⌃⌥C | Center window |
| ⌃⌥= / ⌃⌥- | Wider / narrower |
| ⌃⌥P | Pause / resume |

## Build

Needs only Apple's Command Line Tools (`xcode-select --install`), not Xcode.

```sh
scripts/test.sh        # layout-model tests
scripts/build-app.sh   # → build/Ribbon.app
open build/Ribbon.app
```

On first launch macOS asks for **Accessibility** permission (System Settings →
Privacy & Security → Accessibility). Ribbon starts arranging windows as soon
as it is granted.

Each rebuild is a new ad-hoc signature, so macOS may forget the permission.
If shortcuts stop working after a rebuild, remove Ribbon from the
Accessibility list and add it again.

## Layout

```
Sources/RibbonCore/Strip.swift   pure layout model (columns, focus, scroll, frames)
Sources/Ribbon/AXWindow.swift    Accessibility wrapper for another app's window
Sources/Ribbon/WindowTracker.swift  window discovery + AX notifications
Sources/Ribbon/StripManager.swift   applies the model to real windows
Sources/Ribbon/HotKeys.swift     global shortcuts (Carbon)
Sources/Ribbon/AppDelegate.swift menu bar, permission flow, key bindings
Tests/StripTests.swift           model tests
```

## Roadmap

- Smooth scroll animation
- Stacks (several windows per column) and tabbed columns
- Multiple displays and Spaces (one strip each)
- Trackpad swipe to scroll the strip
- Remember layout across restarts
- Per-app rules, floating windows, settings window, rebindable shortcuts
