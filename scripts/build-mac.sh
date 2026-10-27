#!/bin/bash
# Build a universal Shotli.app and a disk image with the install window.
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"

if ! command -v swiftc >/dev/null 2>&1; then
  echo "swiftc was not found. Install Xcode, then run this script again." >&2
  exit 1
fi

rm -rf "$ROOT/build" "$ROOT/dist"
mkdir -p "$ROOT/build/Shotli.app/Contents/MacOS" "$ROOT/build/Shotli.app/Contents/Resources" "$ROOT/dist"

SDK_PATH="$(xcrun --show-sdk-path 2>/dev/null || true)"
FM_LINK=""
FM_DEFINE=""
if [[ -n "$SDK_PATH" && -d "$SDK_PATH/System/Library/Frameworks/FoundationModels.framework" ]]; then
  FM_LINK="-Xlinker -weak_framework -Xlinker FoundationModels"
  if grep -R -q "struct Attachment" "$SDK_PATH/System/Library/Frameworks/FoundationModels.framework/Modules" 2>/dev/null; then
    FM_DEFINE="-D SHOTLI_APPLE_VISION"
  fi
fi

echo "Compiling arm64…"
swiftc -swift-version 5 -O -parse-as-library \
  -target arm64-apple-macos12.0 \
  $FM_DEFINE \
  -framework AppKit -framework SwiftUI -framework ImageIO -framework UniformTypeIdentifiers -framework CoreImage -framework Vision \
  -Xlinker -weak_framework -Xlinker ScreenCaptureKit \
  $FM_LINK \
  -o "$ROOT/build/Shotli-arm64" \
  "$ROOT"/macos/Sources/Shotli/*.swift

echo "Compiling x86_64…"
swiftc -swift-version 5 -O -parse-as-library \
  -target x86_64-apple-macos12.0 \
  $FM_DEFINE \
  -framework AppKit -framework SwiftUI -framework ImageIO -framework UniformTypeIdentifiers -framework CoreImage -framework Vision \
  -Xlinker -weak_framework -Xlinker ScreenCaptureKit \
  $FM_LINK \
  -o "$ROOT/build/Shotli-x64" \
  "$ROOT"/macos/Sources/Shotli/*.swift

lipo -create -output "$ROOT/build/Shotli.app/Contents/MacOS/Shotli" \
  "$ROOT/build/Shotli-arm64" "$ROOT/build/Shotli-x64"
chmod +x "$ROOT/build/Shotli.app/Contents/MacOS/Shotli"

cp "$ROOT/macos/Info.plist" "$ROOT/build/Shotli.app/Contents/Info.plist"

ICONSET="$ROOT/build/AppIcon.iconset"
mkdir -p "$ICONSET"
sips -z 16 16 "$ROOT/desktop/icon.png" --out "$ICONSET/icon_16x16.png" >/dev/null
sips -z 32 32 "$ROOT/desktop/icon.png" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$ROOT/desktop/icon.png" --out "$ICONSET/icon_32x32.png" >/dev/null
sips -z 64 64 "$ROOT/desktop/icon.png" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$ROOT/desktop/icon.png" --out "$ICONSET/icon_128x128.png" >/dev/null
sips -z 256 256 "$ROOT/desktop/icon.png" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$ROOT/desktop/icon.png" --out "$ICONSET/icon_256x256.png" >/dev/null
sips -z 512 512 "$ROOT/desktop/icon.png" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$ROOT/desktop/icon.png" --out "$ICONSET/icon_512x512.png" >/dev/null
sips -z 1024 1024 "$ROOT/desktop/icon.png" --out "$ICONSET/icon_512x512@2x.png" >/dev/null
iconutil -c icns "$ICONSET" -o "$ROOT/build/Shotli.app/Contents/Resources/AppIcon.icns"
cp "$ROOT/build/Shotli.app/Contents/Resources/AppIcon.icns" "$ROOT/build/VolumeIcon.icns"

codesign --force --sign - "$ROOT/build/Shotli.app"

# 1600×1120 artwork at 144 dpi displays as an 800×560 point window on retina.
cp "$ROOT/macos/dmg/background@2x.png" "$ROOT/build/background.png"
sips -s dpiWidth 144 -s dpiHeight 144 "$ROOT/build/background.png" >/dev/null

if ! command -v create-dmg >/dev/null 2>&1; then
  brew install create-dmg
fi

# Wells in the artwork cover both a centred icon and a top-left Finder position.
set +e
create-dmg \
  --volname "Shotli" \
  --volicon "$ROOT/build/VolumeIcon.icns" \
  --background "$ROOT/build/background.png" \
  --window-pos 200 80 \
  --window-size 800 560 \
  --icon-size 128 \
  --text-size 13 \
  --icon "Shotli.app" 200 250 \
  --hide-extension "Shotli.app" \
  --app-drop-link 600 250 \
  --format ULFO \
  --no-internet-enable \
  --hdiutil-retries 5 \
  --applescript-sleep-duration 8 \
  "$ROOT/dist/Shotli.dmg" \
  "$ROOT/build/Shotli.app"
status=$?
set -e
if [[ ! -f "$ROOT/dist/Shotli.dmg" ]]; then
  echo "create-dmg failed ($status) and did not write dist/Shotli.dmg" >&2
  exit "${status:-1}"
fi

ditto -c -k --keepParent "$ROOT/build/Shotli.app" "$ROOT/dist/Shotli-mac.zip"
ls -lh "$ROOT/dist/Shotli.dmg" "$ROOT/dist/Shotli-mac.zip"
