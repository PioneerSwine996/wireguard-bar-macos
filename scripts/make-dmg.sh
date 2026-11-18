#!/bin/bash
# Builds build/WireGuardBar-<version>.dmg: the app, an Applications shortcut for drag-to-install,
# and a "Helper" folder with the one-time root helper installer (needs sudo, so it stays manual).
set -euo pipefail
cd "$(dirname "$0")/.."

scripts/build-app.sh

version=${CI_COMMIT_TAG:-$(git describe --tags --always --dirty)}
stage=build/dmg
dmg=build/WireGuardBar-$version.dmg
rm -rf "$stage" "$dmg"
mkdir -p "$stage/Helper"

cp -R build/WireGuardBar.app "$stage/"
ln -s /Applications "$stage/Applications"
cp scripts/install-helper.sh scripts/wgbar-helper scripts/patch-wg-quick.sh "$stage/Helper/"
cat > "$stage/Helper/README.txt" <<'EOF'
WireGuard Bar runs tunnels through Homebrew's wireguard-tools and a small root helper.

1. brew install wireguard-tools
2. Copy this Helper folder somewhere (e.g. ~/Downloads), then in Terminal:
     sudo ./install-helper.sh
3. Drag WireGuard Bar to Applications and open it.
   It isn't notarized, so the first time: right-click the app > Open.
4. Import tunnels with the + button in the Manage window.
EOF

hdiutil create -volname "WireGuard Bar" -srcfolder "$stage" -format UDZO -ov "$dmg" >/dev/null
rm -rf "$stage"
echo "Built $dmg"
