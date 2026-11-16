#!/bin/bash
# Builds Notepad.app (release). Pass --install to also copy it to /Applications.
set -euo pipefail
cd "$(dirname "$0")"

APP="Notepad"
BUNDLE="${APP}.app"
ICON="Resources/${APP}.icns"

echo "▸ Building ${APP} (release)…"
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
# Ad-hoc signed by default. Set SIGN_IDENTITY (e.g. "Developer ID Application: …")
# to sign for distribution with the hardened runtime and a secure timestamp.
if [ -n "${SIGN_IDENTITY:-}" ]; then
  echo "▸ Signing with ${SIGN_IDENTITY}…"
  codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$BUNDLE"
else
  codesign --force --sign - "$BUNDLE" >/dev/null 2>&1
fi

echo "✓ Built ${BUNDLE} ($(du -sh "$BUNDLE" | cut -f1))"

if [ "${1:-}" = "--install" ]; then
  rm -rf "/Applications/${BUNDLE}"
  cp -R "$BUNDLE" /Applications/
  echo "✓ Installed to /Applications/${BUNDLE}"
fi
