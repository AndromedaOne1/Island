#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${1:-debug}"
case "$CONFIGURATION" in
    debug|release) ;;
    *) echo "Usage: $0 [debug|release]" >&2; exit 2 ;;
esac

mkdir -p "$ROOT/build" "$ROOT/.cache/clang" "$ROOT/.cache/swiftpm" \
    "$ROOT/.swiftpm/configuration" "$ROOT/.swiftpm/security"
export CLANG_MODULE_CACHE_PATH="$ROOT/.cache/clang"
SWIFT_OPTIONS=(
    --package-path "$ROOT"
    --scratch-path "$ROOT/.build"
    --cache-path "$ROOT/.cache/swiftpm"
    --config-path "$ROOT/.swiftpm/configuration"
    --security-path "$ROOT/.swiftpm/security"
    --disable-sandbox
    --configuration "$CONFIGURATION"
)
swift build "${SWIFT_OPTIONS[@]}" --product Island
BIN_PATH="$(swift build "${SWIFT_OPTIONS[@]}" --show-bin-path)"

STAGING="$(mktemp -d "$ROOT/build/.Island.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT
APP="$STAGING/Island.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
install -m 755 "$BIN_PATH/Island" "$APP/Contents/MacOS/Island"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"
/usr/bin/plutil -lint "$APP/Contents/Info.plist"
/usr/bin/codesign --force --sign - --timestamp=none "$APP"
/usr/bin/codesign --verify --strict "$APP"

# Replace only the generated bundle, after the new build has passed validation.
rm -rf "$ROOT/build/Island.app"
mv "$APP" "$ROOT/build/Island.app"
echo "Built $ROOT/build/Island.app ($CONFIGURATION, ad-hoc signed)"
