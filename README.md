# Dispose

**A scrolling window manager for macOS.**

Dispose lays your windows out side by side on one endless horizontal strip.
Windows never overlap, opening a new one never squeezes the others, and the
strip glides left and right to keep the window you're working in on screen.
Think of it as a filmstrip of your apps that you drive from the keyboard.

```
            ┌──────────────── your screen ────────────────┐
 ┌───────┐  │ ┌───────────┐ ┌─────────────────────────┐   │ ┌───────┐
 │ Mail  │  │ │  Terminal │ │      Safari (focused)   │   │ │ Notes │
 │       │  │ │           │ │                         │   │ │       │
 └───────┘  │ └───────────┘ └─────────────────────────┘   │ └───────┘
            └─────────────────────────────────────────────┘
   ◀ off-screen                                      off-screen ▶
```

The idea comes from [PaperWM](https://github.com/paperwm/PaperWM) and
[niri](https://github.com/YaLTeR/niri) on Linux. Dispose is a native macOS app
written in Swift.

> **Status:** early preview (v0.2). It works day to day on a single display;
> see the [roadmap](#roadmap) for what's coming.

## Features

- **Scrolling columns.** Every window is a column. Columns keep their width
  (⅓, ½, ⅔ or full), and the strip scrolls just enough to show the focused one.
- **New windows open next to you.** They appear right of the focused window
  instead of on top of everything else.
- **Smooth motion.** Windows glide on a spring. Press keys mid-animation and
  they redirect without stopping.
- **Follows you.** Clicking a window, Cmd-Tab and the Dock all move the strip
  to the window you picked.
- **Stays out of the way.** Dialogs, sheets, minimized and fullscreen windows
  are left alone.
- **Nothing gets lost.** Pausing or quitting brings every off-screen window
  back into view.
- **Lightweight.** A menu-bar app with one permission (Accessibility). No
  kernel extensions, no SIP changes, no network access.

## Requirements

- macOS 13 Ventura or later
- Apple silicon (M1 or newer)

## Installation

Dispose is built from source. You need Apple's Command Line Tools, but not
Xcode:

```sh
xcode-select --install          # skip if already installed

git clone https://github.com/aaaxeeell/Dispose.git
cd Dispose
scripts/setup-signing.sh        # once: local signing certificate (see below)
scripts/build-app.sh            # → build/Dispose.app
open build/Dispose.app
```

To keep it, drag `build/Dispose.app` to `/Applications`.

### Granting permission

Dispose moves other apps' windows through the macOS Accessibility API. On
first launch, macOS asks for permission:

1. Click **Open System Settings** in the prompt. If no prompt appears, use the
   Dispose menu-bar icon → **Open Accessibility Settings…**
2. Turn on **Dispose** under *Privacy & Security → Accessibility*.

Dispose starts arranging windows about a second after you turn it on. You don't
need to relaunch it.

### Why the signing script?

macOS remembers the Accessibility permission per app *signature*. An unsigned
(ad-hoc) build gets a new signature every time it's rebuilt, so macOS forgets
the permission. `scripts/setup-signing.sh` creates a self-signed certificate
named **Dispose Local Signing** in your login keychain, and every build is
signed with it, so one approval lasts across rebuilds. The certificate never
leaves your Mac. You can delete it at any time in Keychain Access.

## Usage

Dispose lives in the menu bar (the three-column icon). The menu shows how many
windows it's arranging, lets you pause or re-arrange, and lists every shortcut.

### Keyboard shortcuts

All shortcuts use **Control + Option** (⌃⌥).

| Shortcut | Action |
| --- | --- |
| ⌃⌥ ← / → (or H / L) | Focus the window to the left / right |
| ⌃⌥⌘ ← / → | Focus the first / last window |
| ⌃⌥ 1 … 9 | Focus window 1–9 |
| ⌃⌥⇧ ← / → (or H / L) | Move the focused window left / right |
| ⌃⌥ R | Cycle width: ⅓ → ½ → ⅔ |
| ⌃⌥ F | Toggle full width |
| ⌃⌥ C | Center the focused window |
| ⌃⌥ = / − | Make the window wider / narrower |
| ⌃⌥ P | Pause / resume Dispose |

Shortcuts use physical key positions, so on non-US keyboard layouts the letter
keys are the ones in the H / L / R / F / C positions of a US keyboard.

## Troubleshooting

**Shortcuts do nothing.** Check that the menu-bar menu doesn't say *Waiting for
Accessibility permission*. If Dispose is switched on in System Settings but
still waiting, remove it from the list with **−**, then add it again or
relaunch it. This happens when the list holds an entry from an older build.

**A shortcut doesn't work but the others do.** Another app has probably
claimed that key combination. The log lists any shortcut Dispose couldn't
register.

**Some windows lag behind.** Every window move is a request to the app that
owns the window, and some apps answer slowly. The log names any app that takes
longer than 25 ms.

**The log** is at `~/Library/Logs/Dispose.log`. It's cleared at each launch
and records permission state, shortcut registration, key presses, and slow or
failed window moves. It never records window contents. Window titles appear
only in the list of arranged windows.

## How it works

Dispose keeps a pure model of the strip (the order of columns, their widths,
the focused column and the scroll position) and turns it into window frames.
Windows outside the visible area are parked just past the screen edge, because
macOS doesn't reliably let apps place windows fully off-screen. Moves are sent
on a background queue for each app, so one slow app can't stall the others.
For the details, see [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Roadmap

- [ ] Multiple displays and Spaces (one strip each)
- [ ] Stacks: several windows in one column, plus a tabbed mode
- [ ] Trackpad swipe to scroll the strip
- [ ] Remember the layout across restarts
- [ ] Floating windows and per-app rules
- [ ] Settings window: gaps, animation speed, rebindable shortcuts
- [ ] Launch at login
- [ ] Signed and notarized releases

## Contributing

Bug reports and pull requests are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE) © 2026 axel torres
