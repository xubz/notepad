#!/bin/bash
# Builds Notepad.app (release) into builds/<version>/, version from Resources/Info.plist.
#   ./build.sh            build (ad-hoc signed)
#   ./build.sh --install  …and copy it to /Applications
# Environment:
#   SIGN_IDENTITY   sign for distribution, e.g. "Developer ID Application: Name (TEAMID)"
#                   (hardened runtime + secure timestamp)
#   NOTARY_PROFILE  notarytool keychain profile: notarize, staple, and write builds/<version>/Notepad-<version>.zip
set -euo pipefail
cd "$(dirname "$0")"

APP="Notepad"
ICON="Resources/${APP}.icns"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
OUT="builds/${VERSION}"
BUNDLE="${OUT}/${APP}.app"

echo "▸ Building ${APP} ${VERSION} (release)…"
swift build -c release

if [ ! -f "$ICON" ]; then
  echo "▸ Generating icon…"
  tmp="$(mktemp -d)"
  swift Tools/make-icon.swift "$tmp/${APP}.iconset" >/dev/null
  iconutil -c icns "$tmp/${APP}.iconset" -o "$ICON"
  rm -rf "$tmp"
fi

echo "▸ Packaging ${BUNDLE}…"
rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp ".build/release/${APP}" "$BUNDLE/Contents/MacOS/"
cp "$ICON" "$BUNDLE/Contents/Resources/AppIcon.icns"
cp Resources/Info.plist "$BUNDLE/Contents/Info.plist"

if [ -n "${SIGN_IDENTITY:-}" ]; then
  echo "▸ Signing with ${SIGN_IDENTITY}…"
  codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$BUNDLE"
else
  codesign --force --sign - "$BUNDLE" >/dev/null 2>&1
fi

if [ -n "${NOTARY_PROFILE:-}" ]; then
  [ -n "${SIGN_IDENTITY:-}" ] || { echo "✗ NOTARY_PROFILE needs SIGN_IDENTITY" >&2; exit 1; }
  ZIP="${OUT}/${APP}-${VERSION}.zip"
  echo "▸ Notarizing (this takes a few minutes)…"
  rm -f "$ZIP"
  ditto -c -k --keepParent "$BUNDLE" "$ZIP"
  xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$BUNDLE"
  rm -f "$ZIP"
  ditto -c -k --keepParent "$BUNDLE" "$ZIP"   # re-zip with the stapled ticket
  spctl -a -t exec "$BUNDLE"
  echo "✓ Notarized: ${ZIP}"
fi

echo "✓ Built ${BUNDLE} ($(du -sh "$BUNDLE" | cut -f1))"

if [ "${1:-}" = "--install" ]; then
  rm -rf "/Applications/${APP}.app"
  cp -R "$BUNDLE" /Applications/
  echo "✓ Installed to /Applications/${APP}.app"
fi
