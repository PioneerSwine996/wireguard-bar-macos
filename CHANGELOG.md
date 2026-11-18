## [1.1] - 2026-11-17

### Features

- Tunnels run through a root-owned, patched copy of `wg-quick` that stops it from hammering `configd`/`airportd`.
- Import tunnels from `.conf` files with the + button (helper `import` command; re-run the installer to get it).
- Only one tunnel can be active at a time; errors and App Store WireGuard conflicts show in the menu bar panel.

### Design Rationale

- Stock `wg-quick`'s macOS route monitor re-ran `networksetup` on every network service (17 here) after every
  routing message, including route lookups it and other apps trigger, so it never settled. Ignoring `RTM_GET`/`RTM_MISS`
  and skipping already-correct services removes the churn without changing behavior on real network changes.
- Patching at install time (instead of vendoring) tracks the installed Homebrew version and fails loudly if upstream
  changes the patched lines.

### Notes & Caveats

- Re-run `sudo ./scripts/install-helper.sh` after upgrading wireguard-tools.
- A tunnel that was already up keeps the old monitor until it is turned off and on again.

## [1.0] - 2026-11-17

### Features

- Menu bar panel listing tunnels with on/off switches, transfer and handshake info, and a Manage Tunnels button.
- Tunnels window with per-tunnel overview: enabled, connected to server, data sent/received, latest handshake.
- Touch ID–gated configuration editor with a private-key warning.
- Root helper (`wgbar-helper`) plus installer that adds a narrowly scoped sudoers rule.

### Design Rationale

- Uses Homebrew `wg-quick` instead of a Network Extension, so it needs no paid developer account or provisioning profile.
- One root-owned helper with fixed subcommands instead of sudoers rules on `wg-quick` itself: names are validated
  and configs live in root-owned `/etc/wireguard`, so a symlink in user-writable `/opt/homebrew` can't redirect reads or writes.
- Status is one helper call every 3 seconds, with private and preshared keys redacted before they leave root.

### Notes & Caveats

- Touch ID only gates the app's UI; other processes running as the user can call the helper directly.
- "Connected" means a handshake in the last 3 minutes. An idle tunnel with no keepalive can show "No recent handshake" while still working.
- Changes to a config apply the next time the tunnel is enabled.
