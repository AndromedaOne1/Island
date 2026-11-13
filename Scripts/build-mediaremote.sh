#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${1:-debug}"
case "$CONFIGURATION" in
    debug) OPTIMIZATION=(-O0 -g) ;;
    release) OPTIMIZATION=(-O2) ;;
    *) echo "Usage: $0 [debug|release]" >&2; exit 2 ;;
esac
SOURCE="$ROOT/ThirdParty/MediaRemoteAdapter"
OUTPUT="$ROOT/.cache/mediaremote/$CONFIGURATION"
FRAMEWORK="$OUTPUT/MediaRemoteAdapter.framework"
VERSION="$FRAMEWORK/Versions/A"
mkdir -p "$VERSION/Resources" "$OUTPUT/clang"
SOURCES=("$SOURCE"/src/adapter/*.m "$SOURCE/src/private/MediaRemote.m" "$SOURCE"/src/utility/*.m
    "$ROOT/Resources/MediaRemote/ParentLifetime.m")
xcrun clang "${OPTIMIZATION[@]}" -mmacosx-version-min=14.0 -fobjc-arc \
    -fvisibility=default -fmodules-cache-path="$OUTPUT/clang" \
    -I "$SOURCE/include" -I "$SOURCE/src" -dynamiclib "${SOURCES[@]}" \
    -framework Foundation -framework AppKit -framework UniformTypeIdentifiers \
    -install_name '@rpath/MediaRemoteAdapter.framework/Versions/A/MediaRemoteAdapter' \
    -o "$VERSION/MediaRemoteAdapter"
cat > "$VERSION/Resources/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.vandenbe.MediaRemoteAdapter</string>
<key>CFBundleName</key><string>MediaRemoteAdapter</string>
<key>CFBundleExecutable</key><string>MediaRemoteAdapter</string>
<key>CFBundlePackageType</key><string>FMWK</string>
<key>CFBundleVersion</key><string>0.1.0</string>
<key>CFBundleShortVersionString</key><string>0.1</string>
</dict></plist>
PLIST
ln -sfn A "$FRAMEWORK/Versions/Current"
ln -sfn Versions/Current/MediaRemoteAdapter "$FRAMEWORK/MediaRemoteAdapter"
ln -sfn Versions/Current/Resources "$FRAMEWORK/Resources"
/usr/bin/codesign --force --sign - --timestamp=none "$FRAMEWORK"
/usr/bin/codesign --verify --strict "$FRAMEWORK"

# Explicit upstream probe; it can temporarily publish a synthetic media item.
xcrun clang "${OPTIMIZATION[@]}" -mmacosx-version-min=14.0 -fobjc-arc \
    "$SOURCE/src/test/main.m" "$SOURCE/src/test/NowPlayingTest.m" \
    -framework Foundation -framework MediaPlayer -o "$OUTPUT/MediaRemoteAdapterTestClient"
/usr/bin/codesign --force --sign - --timestamp=none "$OUTPUT/MediaRemoteAdapterTestClient"
echo "$OUTPUT"
