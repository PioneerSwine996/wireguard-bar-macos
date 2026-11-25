#!/bin/bash
# Builds build/WireGuardBar.app (ad-hoc signed; no developer account needed).
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
app=build/WireGuardBar.app
rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
cp .build/release/WireGuardBar "$app/Contents/MacOS/"
# the app installs its own root helper from these (Install Helper, admin prompt)
mkdir -p "$app/Contents/Resources/Helper"
cp scripts/install-helper.sh scripts/wgbar-helper scripts/patch-wg-quick.sh "$app/Contents/Resources/Helper/"
cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>WireGuardBar</string>
    <key>CFBundleIdentifier</key><string>local.wireguardbar</string>
    <key>CFBundleName</key><string>WireGuard Bar</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>15.0</string>
    <key>LSUIElement</key><true/>
    <key>NSLocationUsageDescription</key><string>WireGuard Bar reads the current Wi-Fi network name to turn on-demand tunnels on and off. macOS only shares it with apps that have Location access.</string>
    <key>NSLocationWhenInUseUsageDescription</key><string>WireGuard Bar reads the current Wi-Fi network name to turn on-demand tunnels on and off. macOS only shares it with apps that have Location access.</string>
</dict>
</plist>
PLIST
codesign --force --sign - "$app"
echo "Built $app"
