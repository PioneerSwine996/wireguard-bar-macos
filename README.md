# WireGuard Bar

A small macOS app for running WireGuard tunnels with Homebrew's `wireguard-tools` (`wg-quick` + `wireguard-go`).
It needs no Network Extension, so it runs ad-hoc signed without a paid Apple developer account.

- **Menu bar:** every tunnel with a status dot, an on/off switch, and live transfer and handshake info.
- **Manage Tunnels window:** tunnel list on the left. The overview on the right shows enabled, connected to server, data sent/received, latest handshake, endpoint and interface.
- **Edit Configuration:** warns that the file contains the private key, requires Touch ID (or your login password when Touch ID isn't available), then opens an editor.

## Setup

```bash
brew install wireguard-tools
sudo ./scripts/install-helper.sh
sudo cp ~/Downloads/wg0.conf /etc/wireguard/ && sudo chmod 600 /etc/wireguard/wg0.conf
./scripts/build-app.sh
open build/WireGuardBar.app
```

Copy `build/WireGuardBar.app` to `/Applications` if you want to keep it.
Re-run `sudo ./scripts/install-helper.sh` after `brew upgrade wireguard-tools` to refresh the patched `wg-quick`.

## How it works

The app never runs as root itself. It calls `sudo -n /Library/PrivilegedHelperTools/wgbar-helper` with one of
`status`, `up NAME`, `down NAME`, `read NAME` or `write NAME`. `install-helper.sh` installs that root-owned script and a
sudoers rule that allows your account to run only that script without a password. The helper validates tunnel names,
only touches configs in the root-owned `/etc/wireguard`, and strips private and preshared keys from status output.

Tunnels run through `/Library/PrivilegedHelperTools/wgbar-wg-quick`, a root-owned copy of Homebrew's `wg-quick` that
`scripts/patch-wg-quick.sh` patches at install time. Stock `wg-quick` on macOS rewrites DNS on every network service
after every routing message, including plain route lookups, which keeps `configd` and `airportd` busy while a tunnel
is up. The patch ignores lookups (`RTM_GET`/`RTM_MISS`) and skips services whose DNS is already correct.

## Security notes

- **Touch ID is an in-app check.** Any program running as your user can also run the helper's `read` and `write`
  commands without a prompt, which means it can read private keys or change a config (and `PostUp` lines run as root).
  This is the cost of passwordless toggling. Uninstall with `sudo rm /etc/sudoers.d/wgbar /Library/PrivilegedHelperTools/wgbar-helper`.
- **Homebrew is user-writable.** The `wg-quick` script itself is a root-owned copy, but it still runs `wg`,
  `wireguard-go` and `bash` from `/opt/homebrew`, which your account owns.
