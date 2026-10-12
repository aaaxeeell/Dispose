#!/bin/bash
# Builds build/Dispose.app (Apple silicon). No Xcode needed.
# Signs with "Dispose Local Signing" if present (see setup-signing.sh),
# otherwise ad-hoc.
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/env.sh

APP=build/Dispose.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
swiftc -O -target arm64-apple-macos13.0 -module-name Dispose \
  Sources/DisposeCore/*.swift Sources/Dispose/*.swift \
  -o "$APP/Contents/MacOS/Dispose"
cp Resources/Info.plist "$APP/Contents/Info.plist"
IDENTITY="Dispose Local Signing"
if security find-certificate -c "$IDENTITY" >/dev/null 2>&1; then
  codesign --force --sign "$IDENTITY" "$APP"
else
  echo "warning: no \"$IDENTITY\" certificate; signing ad-hoc. Accessibility" >&2
  echo "permission will reset on every rebuild. Run scripts/setup-signing.sh." >&2
  codesign --force --sign - "$APP"
fi
echo "Built $APP"
