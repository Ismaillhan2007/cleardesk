#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
VERSION="${1:-1.0.0}"
APP_BUNDLE="$DIST_DIR/ClearDesk.app"
DMG_STAGING="$DIST_DIR/dmg-staging"
DMG_PATH="$DIST_DIR/ClearDesk-${VERSION}.dmg"
SHA_PATH="${DMG_PATH}.sha256"

# Build fresh ClearDesk.app first
"$ROOT_DIR/scripts/build_app.sh"

# Optional: sign with a Developer ID certificate if provided via CODESIGN_IDENTITY
if [ -n "${CODESIGN_IDENTITY:-}" ]; then
  echo "Signing ClearDesk.app with Developer ID: $CODESIGN_IDENTITY"
  codesign --force --deep --options runtime --timestamp --sign "$CODESIGN_IDENTITY" "$APP_BUNDLE"
fi

echo "Packaging ClearDesk-${VERSION}.dmg..."
rm -rf "$DMG_STAGING" "$DMG_PATH" "$SHA_PATH"
mkdir -p "$DMG_STAGING"

cp -R "$APP_BUNDLE" "$DMG_STAGING/ClearDesk.app"
ln -s /Applications "$DMG_STAGING/Applications"

hdiutil create \
  -volname "ClearDesk ${VERSION}" \
  -srcfolder "$DMG_STAGING" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

rm -rf "$DMG_STAGING"

# Optional: sign the DMG itself if a Developer ID identity is supplied
if [ -n "${CODESIGN_IDENTITY:-}" ]; then
  codesign --force --timestamp --sign "$CODESIGN_IDENTITY" "$DMG_PATH"
fi

# Generate SHA-256 checksum for user verification
(cd "$DIST_DIR" && shasum -a 256 "ClearDesk-${VERSION}.dmg" > "ClearDesk-${VERSION}.dmg.sha256")

echo "Done:"
echo "  DMG:    $DMG_PATH"
echo "  SHA256: $(cat "$SHA_PATH")"
