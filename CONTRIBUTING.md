# Contributing to Dispose

Thanks for helping out! Bug reports, ideas and pull requests are all welcome.

## Reporting a bug

Please include:

- your macOS version and Mac model,
- what you did, what you expected, and what happened,
- the apps involved (some apps respond to window moves differently),
- the relevant part of `~/Library/Logs/Dispose.log`. It's cleared at each
  launch, so copy it right after the problem happens.

## Development setup

You need the Command Line Tools (`xcode-select --install`). Xcode is optional.

```sh
scripts/setup-signing.sh   # once
scripts/test.sh            # model tests
scripts/build-app.sh       # builds build/Dispose.app
open build/Dispose.app
```

Quit the running copy before you launch a new build. The menu-bar icon has
**Quit Dispose**, or run `pkill -x Dispose`.

Read [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) before making larger changes.

## Guidelines

- **Layout logic belongs in `DisposeCore`** and gets a test in
  `Tests/StripTests.swift`. Keep it free of AppKit and side effects.
- **Don't make AX calls on the main thread in hot paths.** Route window
  updates through `WindowMover`.
- **Never lose a window.** Any change that parks windows off-screen must keep
  `releaseWindows()` working on pause and quit.
- Match the surrounding style: small types, comments that explain *why*.
- Keep pull requests focused. Note user-visible changes in `CHANGELOG.md`
  under *Unreleased*.
