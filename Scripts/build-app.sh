#!/bin/zsh
# Build MSXPET.app from SwiftPM (no Xcode required).
set -euo pipefail
cd "$(dirname "$0")/.."
APP="dist/MSXPET.app"
rm -rf dist
swift build -c release
BIN="$(swift build -c release --show-bin-path)/MSXPET"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/MSXPET"
cp Resources/Info.plist "$APP/Contents/Info.plist"
if [[ -d Sources/MSXPET/Resources/pets ]]; then
  cp -R Sources/MSXPET/Resources/pets "$APP/Contents/Resources/"
fi
echo "Built $APP"
echo "Run: open $APP"
