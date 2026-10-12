#!/bin/bash
# Builds Dispose.app and zips it for a GitHub release:
#   build/Dispose-<version>.zip
set -euo pipefail
cd "$(dirname "$0")/.."
scripts/test.sh
scripts/build-app.sh

VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)
ZIP="build/Dispose-$VERSION.zip"
codesign --verify --strict build/Dispose.app
# ditto keeps the code signature and extended attributes intact.
ditto -c -k --keepParent build/Dispose.app "$ZIP"
echo "Packaged $ZIP"
shasum -a 256 "$ZIP"
