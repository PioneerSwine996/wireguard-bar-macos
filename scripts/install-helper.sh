#!/bin/bash
# Installs the root helper and a sudoers rule that lets your account run only that helper
# without a password. Run once: sudo ./scripts/install-helper.sh
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "Run with sudo: sudo $0" >&2; exit 1; }
user=${SUDO_USER:?Run through sudo from your own account}
here=$(cd "$(dirname "$0")" && pwd)

install -m 755 -o root -g wheel "$here/wgbar-helper" /Library/PrivilegedHelperTools/wgbar-helper
install -d -m 700 -o root -g wheel /etc/wireguard

rule=$(mktemp)
echo "$user ALL=(root) NOPASSWD: /Library/PrivilegedHelperTools/wgbar-helper" > "$rule"
visudo -cf "$rule"
install -m 440 -o root -g wheel "$rule" /etc/sudoers.d/wgbar
rm -f "$rule"

echo "Installed. Put tunnel configs in /etc/wireguard (e.g. sudo cp wg0.conf /etc/wireguard/ && sudo chmod 600 /etc/wireguard/wg0.conf)."
