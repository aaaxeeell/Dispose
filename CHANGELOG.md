# Changelog

All notable changes to Dispose are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Fixed
- Windows could be left stranded off-screen when Dispose quit: off-screen
  windows are now brought back before the app exits, and `kill`, `pkill`
  and logout go through the same clean quit.

## [0.2.0] - 2026-10-12

### Added
- Spring animation: windows glide to their new positions and redirect
  smoothly when a new command arrives mid-motion.
- Diagnostics log at `~/Library/Logs/Dispose.log`.
- `scripts/setup-signing.sh`: a local signing certificate so the
  Accessibility permission survives rebuilds.

### Changed
- Window moves run on a background queue for each app, so slow apps no
  longer stall hotkeys or animation.

### Fixed
- Quick focus changes could pull focus back to an earlier window.
- Each focus change triggered several redundant layout passes.

## [0.1.0] - 2026-10-12

### Added
- First prototype: windows as columns on a horizontally scrolling strip.
- Keyboard focus, move, width presets, full width, center, pause.
- Follows focus changes from mouse clicks, Cmd-Tab and the Dock.
- Menu-bar app with an Accessibility permission flow.
