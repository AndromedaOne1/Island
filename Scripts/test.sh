#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${1:-debug}"
case "$CONFIGURATION" in
    debug|release) ;;
    *) echo "Usage: $0 [debug|release]" >&2; exit 2 ;;
esac

mkdir -p "$ROOT/.cache/clang" "$ROOT/.cache/swiftpm" \
    "$ROOT/.swiftpm/configuration" "$ROOT/.swiftpm/security"
export CLANG_MODULE_CACHE_PATH="$ROOT/.cache/clang"
OPTIONS=(
    --package-path "$ROOT"
    --scratch-path "$ROOT/.cache/test-build-${ISLAND_TEST_BUILD_SYSTEM:-swiftbuild}"
    --build-system "${ISLAND_TEST_BUILD_SYSTEM:-swiftbuild}"
    --disable-sandbox --disable-xctest
    --cache-path "$ROOT/.cache/swiftpm"
    --config-path "$ROOT/.swiftpm/configuration"
    --security-path "$ROOT/.swiftpm/security"
    --configuration "$CONFIGURATION"
)

# CLT 6.4 can omit the Testing macro plugin from the generated test build plan.
# Locate installed toolchain resources rather than depending on an Xcode path.
SWIFT_BIN="$(dirname "$(xcrun --find swiftc)")"
PLUGIN="$SWIFT_BIN/../lib/swift/host/plugins/testing/libTestingMacros.dylib"
if [[ -f "$PLUGIN" ]]; then
    OPTIONS+=(-Xswiftc -load-plugin-library -Xswiftc "$PLUGIN")
fi
DEVELOPER="$(xcode-select -p)"
for FRAMEWORKS in "$DEVELOPER/Library/Developer/Frameworks" \
    "$DEVELOPER/Platforms/MacOSX.platform/Developer/Library/Frameworks"; do
    if [[ -d "$FRAMEWORKS/Testing.framework" ]]; then
        OPTIONS+=(-Xswiftc -F -Xswiftc "$FRAMEWORKS"
            -Xlinker -F -Xlinker "$FRAMEWORKS"
            -Xlinker -rpath -Xlinker "$FRAMEWORKS")
        break
    fi
done
swift test "${OPTIONS[@]}"
