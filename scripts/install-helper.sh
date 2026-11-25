#!/bin/bash
# Installs the root helper and a sudoers rule that lets one account run only that helper
# without a password. WireGuard Bar runs this for you (Install Helper, with an administrator
# prompt); by hand: sudo ./scripts/install-helper.sh [username]
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "Run with sudo: sudo $0" >&2; exit 1; }
user=${1:-${SUDO_USER:-}}
[[ "$user" =~ ^[A-Za-z0-9._-]+$ ]] && [ "$user" != root ] && id "$user" >/dev/null 2>&1 \
  || { echo "Pass the account to allow, e.g. sudo $0 \$(whoami)" >&2; exit 1; }
[ -x /opt/homebrew/bin/wg-quick ] || { echo "Install wireguard-tools first: brew install wireguard-tools" >&2; exit 1; }
here=$(cd "$(dirname "$0")" && pwd)

install -m 755 -o root -g wheel "$here/wgbar-helper" /Library/PrivilegedHelperTools/wgbar-helper

# Root-owned, patched wg-quick (see patch-wg-quick.sh). Re-run this script after `brew upgrade wireguard-tools`.
patched=$(mktemp)
"$here/patch-wg-quick.sh" /opt/homebrew/bin/wg-quick "$patched"
install -m 755 -o root -g wheel "$patched" /Library/PrivilegedHelperTools/wgbar-wg-quick
rm -f "$patched"
install -d -m 700 -o root -g wheel /etc/wireguard

rule=$(mktemp)
echo "$user ALL=(root) NOPASSWD: /Library/PrivilegedHelperTools/wgbar-helper" > "$rule"
visudo -cf "$rule"
install -m 440 -o root -g wheel "$rule" /etc/sudoers.d/wgbar
rm -f "$rule"

echo "Installed. Put tunnel configs in /etc/wireguard (e.g. sudo cp wg0.conf /etc/wireguard/ && sudo chmod 600 /etc/wireguard/wg0.conf)."
