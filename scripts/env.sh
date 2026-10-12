# Shared build settings. Builds call swiftc directly (no SwiftPM/Xcode needed).
# Pick the newest SDK the installed compiler can actually build against: a
# Command Line Tools install can ship an SDK newer than its compiler.
if [ -z "${SDKROOT:-}" ]; then
  for sdk in $(ls -d /Library/Developer/CommandLineTools/SDKs/MacOSX[0-9]*.*.sdk 2>/dev/null | sort -rV); do
    if echo 'import AppKit' | swiftc -sdk "$sdk" -typecheck - >/dev/null 2>&1; then
      export SDKROOT="$sdk"; break
    fi
  done
fi
: "${SDKROOT:?No usable macOS SDK found. Install Command Line Tools: xcode-select --install}"
BUILD_DIR="$(pwd)/.build"
mkdir -p "$BUILD_DIR"
