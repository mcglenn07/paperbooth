#!/bin/zsh
set -euo pipefail
SOURCE_DIR="$(cd "$(dirname "$0")" && pwd)"
DESTINATION="${1:-$SOURCE_DIR/build/Paperbooth.app}"
BUILD_CACHE="${TMPDIR:-/tmp}/paperbooth-module-cache"
mkdir -p "$DESTINATION/Contents/MacOS" "$DESTINATION/Contents/Resources" "$BUILD_CACHE"
xcrun swiftc -swift-version 5 -parse-as-library -O \
    -target arm64-apple-macosx14.0 -module-cache-path "$BUILD_CACHE" \
    -framework SwiftUI -framework AppKit -framework AVFoundation \
    -framework ImageIO -framework UniformTypeIdentifiers \
    "$SOURCE_DIR"/Sources/*.swift -o "$DESTINATION/Contents/MacOS/Paperbooth"
cp "$SOURCE_DIR/Info.plist" "$DESTINATION/Contents/Info.plist"
if [[ -f "$SOURCE_DIR/AppIcon.icns" ]]; then cp "$SOURCE_DIR/AppIcon.icns" "$DESTINATION/Contents/Resources/AppIcon.icns"; fi
codesign --force --sign - "$DESTINATION"
echo "Built: $DESTINATION"
