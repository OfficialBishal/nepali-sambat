#!/usr/bin/env bash
# Builds "Nepali Patro.app" (universal, ad-hoc signed) and a DMG into ./dist.
# Needs only the Xcode Command Line Tools.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${VERSION:-$(cat VERSION)}"
BUILD="${BUILD:-$(git rev-list --count HEAD 2>/dev/null || echo 1)}"
APP_NAME="Nepali Patro"
DIST="dist"
APP="$DIST/$APP_NAME.app"
DMG="$DIST/NepaliPatro-$VERSION.dmg"

echo "==> Building $APP_NAME $VERSION ($BUILD)"
swift build -c release --arch arm64 --arch x86_64
BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"

echo "==> Assembling bundle"
rm -rf "$APP" "$DMG"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/PlugIns"
cp "$BIN/NepaliPatro" "$APP/Contents/MacOS/NepaliPatro"
cp "$BIN/patro" "$APP/Contents/MacOS/patro"
sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD/" Resources/App-Info.plist > "$APP/Contents/Info.plist"
printf "APPL????" > "$APP/Contents/PkgInfo"

APPEX="$APP/Contents/PlugIns/NepaliPatroWidgets.appex"
mkdir -p "$APPEX/Contents/MacOS"
cp "$BIN/NepaliPatroWidgets" "$APPEX/Contents/MacOS/NepaliPatroWidgets"
sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD/" Resources/Widgets-Info.plist > "$APPEX/Contents/Info.plist"

echo "==> Icon"
ICONSET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$ICONSET"
[ -f Resources/icon-1024.png ] || swift scripts/make-icon.swift Resources/icon-1024.png
for s in 16 32 128 256 512; do
  sips -z $s $s Resources/icon-1024.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  sips -z $((s * 2)) $((s * 2)) Resources/icon-1024.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

echo "==> Signing (ad-hoc)"
xattr -cr "$APP"
codesign --force --sign - --entitlements Resources/Widgets.entitlements --options runtime "$APPEX"
codesign --force --sign - "$APP/Contents/MacOS/patro"
codesign --force --sign - "$APP"
codesign --verify --strict --verbose=1 "$APP"

echo "==> DMG"
STAGE="$(mktemp -d)"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"

shasum -a 256 "$DMG"
echo "==> Done: $APP and $DMG"
