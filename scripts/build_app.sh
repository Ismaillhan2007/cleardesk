#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/ClearDesk.app"
ICONSET_DIR="$DIST_DIR/AppIcon.iconset"
ICNS_FILE="$DIST_DIR/AppIcon.icns"

echo "1/4 Generating minimalist macOS app icon..."
mkdir -p "$DIST_DIR"
swift "$ROOT_DIR/scripts/generate_icon.swift" "$ICNS_FILE"

echo "2/4 Building ClearDeskApp (release)..."
cd "$ROOT_DIR"
swift build -c release --disable-sandbox
BIN_PATH="$ROOT_DIR/.build/release/ClearDeskApp"

echo "3/4 Assembling ClearDesk.app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BIN_PATH" "$APP_BUNDLE/Contents/MacOS/ClearDesk"
chmod +x "$APP_BUNDLE/Contents/MacOS/ClearDesk"
cp "$ICNS_FILE" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
rm -f "$ICNS_FILE"

cat > "$APP_BUNDLE/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>ClearDesk</string>
    <key>CFBundleExecutable</key>
    <string>ClearDesk</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.ismaillhan2007.cleardesk</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>ClearDesk</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.productivity</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSDesktopFolderUsageDescription</key>
    <string>ClearDesk watches your Desktop and moves settled items into your local Vault when you sweep.</string>
</dict>
</plist>
EOF

echo "4/4 Ad-hoc code signing ClearDesk.app..."
codesign --force --deep --sign - "$APP_BUNDLE"

echo "Done: $APP_BUNDLE"
