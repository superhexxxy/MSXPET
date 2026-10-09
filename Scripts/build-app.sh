#!/bin/zsh
# Build MSXPET.app from SwiftPM (no Xcode required).
# Ad-hoc signs so it runs locally without a paid Developer ID.
# Usage: zsh Scripts/build-app.sh [--zip|--dmg]
set -euo pipefail
cd "$(dirname "$0")/.."
APP="dist/MSXPET.app"
rm -rf dist
swift build -c release
BIN="$(swift build -c release --show-bin-path)/MSXPET"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/MSXPET"
cp Resources/Info.plist "$APP/Contents/Info.plist"
if [[ -f Sources/MSXPET/Resources/MSXPET.icns ]]; then
  cp Sources/MSXPET/Resources/MSXPET.icns "$APP/Contents/Resources/MSXPET.icns"
fi
if [[ -d Sources/MSXPET/Resources/pets ]]; then
  cp -R Sources/MSXPET/Resources/pets "$APP/Contents/Resources/"
fi
codesign --force --deep --sign - "$APP"
echo "Built $APP"

if [[ "${1:-}" == "--zip" ]]; then
  (cd dist && zip -qr MSXPET.zip MSXPET.app)
  echo "Wrote dist/MSXPET.zip"
elif [[ "${1:-}" == "--dmg" ]]; then
  hdiutil create -volname MSXPET -srcfolder "$APP" -ov -format UDZO dist/MSXPET.dmg
  echo "Wrote dist/MSXPET.dmg"
fi
echo "Run: open $APP"
