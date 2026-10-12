# Architecture

Dispose is a small AppKit menu-bar app with two layers: a pure layout model
that is easy to test, and a thin layer that turns the model into real windows
through the Accessibility (AX) API.

```
 hotkeys ─┐                       ┌─────────────┐
          ├─► StripManager ──────►│ Strip model │  (DisposeCore, pure)
 AX/NSWorkspace events ─┘   │     └─────────────┘
          (WindowTracker)   │ target frames
                            ▼
                 spring animation (120 Hz)
                            │ positions / sizes
                            ▼
                 WindowMover (one queue per app) ──► AXUIElement set calls
```

## Source map

| File | Responsibility |
| --- | --- |
| `Sources/DisposeCore/Strip.swift` | The strip model: columns, widths, focus, scroll, frame calculation. No AppKit, no side effects. |
| `Sources/Dispose/StripManager.swift` | Owns a `Strip`, reacts to window events and commands, computes targets, runs the spring animation. |
| `Sources/Dispose/WindowMover.swift` | Applies moves on a background queue for each app, keeping only the newest request. |
| `Sources/Dispose/WindowTracker.swift` | Finds windows and observes created, destroyed, minimized and focused events for each app. |
| `Sources/Dispose/AXWindow.swift` | Wrapper around another app's window (`AXUIElement`): frame, eligibility, focus. |
| `Sources/Dispose/HotKeys.swift` | Global shortcuts using Carbon's `RegisterEventHotKey`. |
| `Sources/Dispose/AppDelegate.swift` | Menu bar, permission flow, default key bindings. |
| `Sources/Dispose/Log.swift` | Diagnostics log at `~/Library/Logs/Dispose.log`. |
| `Tests/StripTests.swift` | Tests for the model, with no dependencies. |

## The strip model

Each column has a width given as a fraction of the *usable* width (the screen
minus its outer gaps). Pixel widths are defined as

```
pixelWidth = fraction × (usable + gap) − gap
```

so that, for example, two ½ columns and the gap between them fill the usable
width exactly.

Columns are laid out left to right in *strip coordinates*. `scroll` is the
strip x-coordinate shown at the left edge of the screen. When focus changes,
`revealFocused` scrolls by the smallest amount that brings the focused column
fully into view (or centers it, when asked).

## Placing windows

`StripManager.layout()` converts the model into a target frame for each
window. Columns that are entirely off-screen get *parked*: placed just past
the nearest screen edge with a 1 px sliver showing. macOS tends to pull
windows back on screen when an app moves them fully off-screen, and parking
avoids that.

Coordinates follow the AX convention: global, with the origin at the top-left
of the primary display and y growing downwards. `Screen.viewport()` converts
`NSScreen.visibleFrame` (bottom-left origin) into that space.

## Animation

Each moving window has a critically damped spring: position, velocity and
target, integrated at 120 Hz (`omega = 26`, which settles in about 0.25 s).
A new command only changes the target. Velocity is kept, so pressing keys
quickly redirects windows smoothly instead of restarting the motion.

Only position is animated. Size is applied once, at the start, because
resizing on every frame makes apps re-layout their content constantly.

## Why moves happen off the main thread

Every AX call is a synchronous round trip to the app that owns the window.
Typical apps answer in 25–70 ms, and a busy one can take several hundred.
Making those calls on the main thread would freeze animation and hotkeys.

`WindowMover` gives each app its own serial queue. A request records the
latest position, size or focus for a window, and the queue applies it when
it's free. If an app is slow, the intermediate frames are dropped, so it
never builds up a backlog.

Focus changes also go through the mover. Because they're asynchronous, the
manager ignores focus events from other windows for 0.5 s after it requests
focus. Otherwise a late echo from an earlier key press could pull focus back.

## Which windows are managed

A window is tiled if it has role `AXWindow` and subrole `AXStandardWindow`,
isn't minimized or in native fullscreen, and has a size and position that can
be set. That excludes dialogs, sheets, panels, popovers and most utility
windows.

## Building without SwiftPM

`scripts/build-app.sh` and `scripts/test.sh` call `swiftc` directly instead of
`swift build`, so the project builds with Command Line Tools installs where
SwiftPM is broken or the default SDK is newer than the compiler
(`scripts/env.sh` picks a matching SDK). `Package.swift` is kept so
SwiftPM-aware editors can index the code.
