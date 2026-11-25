# WireGuard Bar

A menu bar app for macOS that runs WireGuard tunnels with Homebrew's `wireguard-tools`.

It doesn't use a Network Extension, so it doesn't need an Apple developer account or the App Store, and it keeps
working when the official app doesn't. A Windows version lives in
[wireguard-bar-windows](https://gitlab.com/PioneerSwine996/wireguard-bar-windows).

- **Menu bar:** every tunnel with Connect / Disconnect. The icon shows whether a tunnel is on, and whether it routes
  all traffic (locked shield) or only your home network (unlocked shield).
- **Manage window:** an animated globe showing the route your traffic takes, plus connection status, data sent and
  received, latest handshake and endpoint. The sidebar collapses to numbered badges.
- **One tunnel at a time:** connecting one disconnects the others.
- **Route all traffic:** off sends only the tunnel's own subnets and DNS through the VPN; everything else uses your
  current network. Your config file is never changed.
- **On-Demand:** connect automatically on chosen Wi-Fi networks and disconnect when you leave them.
- **Import and edit:** add tunnels from `.conf` files; editing a config requires Touch ID.

Requires macOS 15 or later on Apple silicon or Intel.

## Install

1. Install the WireGuard tools:

   ```bash
   brew install wireguard-tools
   ```

2. Download the latest DMG:
   [WireGuardBar.dmg](https://gitlab.com/PioneerSwine996/wireguard/-/jobs/artifacts/main/raw/WireGuardBar.dmg?job=dmg)
3. Open it, drag **WireGuard Bar** to Applications, and copy the **Helper** folder somewhere (for example
   Downloads).
4. Install the helper once (it asks for your password):

   ```bash
   sudo ~/Downloads/Helper/install-helper.sh
   ```

5. Open WireGuard Bar. The app isn't notarized, so the first time, right-click it and choose **Open**.
6. Click **Manage**, then **+** to import your tunnel's `.conf` file.

Re-run the helper installer after `brew upgrade wireguard-tools`.

## Build from source

```bash
git clone https://gitlab.com/PioneerSwine996/wireguard.git
cd wireguard
swift test
scripts/build-app.sh          # build/WireGuardBar.app
scripts/make-dmg.sh           # build/WireGuardBar-<version>.dmg
sudo scripts/install-helper.sh
```

Needs Xcode 16 or later (Swift 6).

## How it works

The app never runs as root. It calls one root-owned script, `/Library/PrivilegedHelperTools/wgbar-helper`, through
`sudo -n`, and the installer adds a sudoers rule that lets your account run only that script without a password. The
helper accepts a fixed set of commands (`status`, `up`, `down`, `addresses`, `read`, `write`, `import`), validates
tunnel names, only touches configs in the root-owned `/etc/wireguard`, and strips private and preshared keys from
status output.

Tunnels run through a root-owned copy of Homebrew's `wg-quick`, patched at install time
(`scripts/patch-wg-quick.sh`). Stock `wg-quick` on macOS rewrites DNS on every network service after every routing
message, including plain route lookups, which keeps `configd` and `airportd` busy while a tunnel is up. The patch
ignores lookups and skips services whose DNS is already correct.

With **Route all traffic** off, the helper connects with a root-only copy of the config in `/var/run/wgbar` whose
`AllowedIPs` lists only the tunnel's `Address` subnets (host addresses widened to /24 or /64) and its DNS servers.

On-Demand reads the current Wi-Fi name, which macOS only reveals to apps with Location access, so the app asks for
it the first time you use that section.

## Security

- **Touch ID only protects the app's editor.** Any program running as your user can call the helper's `read` and
  `write` commands without a prompt, so it could read private keys or change a config (and `PostUp` lines run as
  root). That's the cost of passwordless connecting.
- **Homebrew is user-writable.** The `wg-quick` script is a root-owned copy, but it still runs `wg`,
  `wireguard-go` and `bash` from `/opt/homebrew`, which your account owns.

Report security issues privately to the maintainer on GitLab rather than in a public issue.

### Uninstall

```bash
sudo rm /etc/sudoers.d/wgbar /Library/PrivilegedHelperTools/wgbar-helper /Library/PrivilegedHelperTools/wgbar-wg-quick
```

Then delete the app. Your tunnel configs stay in `/etc/wireguard`.

## Contributing

The main repository is on [GitLab](https://gitlab.com/PioneerSwine996/wireguard). Pull requests are welcome on the
[GitHub mirror](https://github.com/PioneerSwine996/wireguard-bar-macos); see [CONTRIBUTING.md](CONTRIBUTING.md).

## Credits and license

MIT; see [LICENSE](LICENSE). The connecting animation is a port of
[thinking-orbs](https://github.com/Jakubantalik/thinking-orbs) by Jakub Antalik (MIT).

WireGuard is a registered trademark of Jason A. Donenfeld. This project is not affiliated with or endorsed by the
WireGuard project.
