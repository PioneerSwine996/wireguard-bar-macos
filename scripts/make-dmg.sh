#!/bin/bash
# Builds build/WireGuardBar-<version>.dmg: the app and an Applications shortcut for drag-to-install.
# The app installs wireguard-tools and its root helper itself on first launch.
set -euo pipefail
cd "$(dirname "$0")/.."

scripts/build-app.sh

version=${CI_COMMIT_TAG:-$(git describe --tags --always --dirty)}
stage=build/dmg
dmg=build/WireGuardBar-$version.dmg
rm -rf "$stage" "$dmg"
mkdir -p "$stage"

cp -R build/WireGuardBar.app "$stage/"
ln -s /Applications "$stage/Applications"

hdiutil create -volname "WireGuard Bar" -srcfolder "$stage" -format UDZO -ov "$dmg" >/dev/null
rm -rf "$stage"
echo "Built $dmg"
