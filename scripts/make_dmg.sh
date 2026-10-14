#!/bin/zsh
# Builds Cloudy.app, then packages it with a drag-to-Applications install shortcut.
# Usage: scripts/make_dmg.sh [--no-build]   -> Cloudy-<version>.dmg (+ .sha256)
set -euo pipefail
cd "$(dirname "$0")/.."

[[ "${1:-}" == "--no-build" ]] || ./scripts/build_app.sh

APP=Cloudy.app
[[ -d "$APP" ]] || { echo "Run ./scripts/build_app.sh first." >&2; exit 1; }
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")
STAGING=$(mktemp -d "${TMPDIR:-/tmp}/cloudy-dmg.XXXXXX")
trap 'rm -rf "$STAGING"' EXIT
ditto "$APP" "$STAGING/Cloudy.app"
ln -s /Applications "$STAGING/Applications"
cat > "$STAGING/Install.txt" <<'TXT'
Cloudy — macOS 14 or later, Apple silicon

Drag Cloudy.app onto Applications, then eject this disk image.

This release is not notarized by Apple, so macOS may block the first launch.
If you trust this download, attempt to open the app, then use
System Settings > Privacy & Security > Open Anyway.

Widgets: open Cloudy once, then right-click the desktop, choose
Edit Widgets… and search for Cloudy.
TXT
OUTPUT="Cloudy-${VERSION}.dmg"
hdiutil create -volname Cloudy -srcfolder "$STAGING" -format UDZO -ov "$OUTPUT" >/dev/null
hdiutil verify "$OUTPUT" >/dev/null
shasum -a 256 "$OUTPUT" > "$OUTPUT.sha256"
echo "Created $OUTPUT ($(du -h "$OUTPUT" | cut -f1))"
