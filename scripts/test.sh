#!/bin/bash
# Builds and runs the layout-model tests.
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/env.sh
swiftc -O -parse-as-library -module-name StripTests \
  Sources/RibbonCore/*.swift Tests/*.swift -o "$BUILD_DIR/strip-tests"
"$BUILD_DIR/strip-tests"
