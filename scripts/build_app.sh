#!/bin/bash
# Builds Cloudy in release mode and packages it into a double-clickable
# Cloudy.app bundle at the repo root.
set -euo pipefail

cd "$(dirname "$0")/.."
export DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}

source scripts/shared_sources.sh

# Signing: widgets need a real (Apple Development / Developer ID) identity
# because the extension must be sandboxed and share an App Group.
IDENTITY=${CODESIGN_IDENTITY:-$(security find-identity -v -p codesigning | awk -F'"' '/Apple Development|Developer ID Application/ {print $2; exit}')}
TEAM=""
if [ -n "$IDENTITY" ]; then
    TEAM=$(security find-certificate -c "$IDENTITY" -p | openssl x509 -noout -subject | sed -n 's/.*OU=\([A-Z0-9]*\).*/\1/p')
fi
GROUP=${TEAM:+$TEAM.dev.cloudy}

swift build -c release

APP="Cloudy.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Cloudy "$APP/Contents/MacOS/Cloudy"

# App icon
ICONSET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$ICONSET"
swift scripts/generate_icon.swift "$ICONSET/icon_1024.png" >/dev/null
for s in 16 32 128 256 512; do
    sips -z $s $s "$ICONSET/icon_1024.png" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
    sips -z $((s * 2)) $((s * 2)) "$ICONSET/icon_1024.png" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
rm "$ICONSET/icon_1024.png"
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Cloudy</string>
    <key>CFBundleIdentifier</key>
    <string>dev.cloudy.app</string>
    <key>CFBundleName</key>
    <string>Cloudy</string>
    <key>CFBundleDisplayName</key>
    <string>Cloudy</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.weather</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSLocationUsageDescription</key>
    <string>Cloudy uses your location to show the weather where you are.</string>
    <key>NSLocationWhenInUseUsageDescription</key>
    <string>Cloudy uses your location to show the weather where you are.</string>
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key>
            <string>dev.cloudy.app</string>
            <key>CFBundleURLSchemes</key>
            <array><string>cloudy</string></array>
        </dict>
    </array>
    <key>CloudyAppGroup</key>
    <string>${GROUP}</string>
</dict>
</plist>
PLIST

if [ -z "$GROUP" ]; then
    codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true
    echo "Built $APP (no signing identity found — widgets skipped)"
    exit 0
fi

# Widget extension
APPEX="$APP/Contents/PlugIns/CloudyWidgets.appex"
mkdir -p "$APPEX/Contents/MacOS"
xcrun swiftc -O -parse-as-library -swift-version 5 -module-name CloudyWidgets -application-extension -Xlinker -application_extension \
    -target arm64-apple-macos14.0 -sdk "$(xcrun --sdk macosx --show-sdk-path)" \
    "${SHARED_SOURCES[@]}" Widgets/Provider.swift Widgets/WidgetViews.swift Widgets/CloudyWidgets.swift \
    -o "$APPEX/Contents/MacOS/CloudyWidgets"

cat > "$APPEX/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>CloudyWidgets</string>
    <key>CFBundleIdentifier</key>
    <string>dev.cloudy.app.widgets</string>
    <key>CFBundleName</key>
    <string>Cloudy Widgets</string>
    <key>CFBundleDisplayName</key>
    <string>Cloudy</string>
    <key>CFBundlePackageType</key>
    <string>XPC!</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleSupportedPlatforms</key>
    <array><string>MacOSX</string></array>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSExtension</key>
    <dict>
        <key>NSExtensionPointIdentifier</key>
        <string>com.apple.widgetkit-extension</string>
    </dict>
    <key>CloudyAppGroup</key>
    <string>${GROUP}</string>
</dict>
</plist>
PLIST

ENT_DIR=$(mktemp -d)
cat > "$ENT_DIR/widget.entitlements" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key><true/>
    <key>com.apple.security.network.client</key><true/>
    <key>com.apple.security.application-groups</key>
    <array><string>${GROUP}</string></array>
</dict>
</plist>
PLIST
cat > "$ENT_DIR/app.entitlements" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.application-groups</key>
    <array><string>${GROUP}</string></array>
</dict>
</plist>
PLIST

codesign --force --sign "$IDENTITY" --entitlements "$ENT_DIR/widget.entitlements" --timestamp=none "$APPEX"
codesign --force --sign "$IDENTITY" --entitlements "$ENT_DIR/app.entitlements" --timestamp=none "$APP"
echo "Built $APP with widgets (signed: $IDENTITY, group: $GROUP)"
