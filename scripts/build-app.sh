#!/bin/bash
# Builds build/Ribbon.app (Apple silicon, ad-hoc signed). No Xcode needed.
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/env.sh

APP=build/Ribbon.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
swiftc -O -target arm64-apple-macos13.0 -module-name Ribbon \
  Sources/RibbonCore/*.swift Sources/Ribbon/*.swift \
  -o "$APP/Contents/MacOS/Ribbon"
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
echo "Built $APP"
