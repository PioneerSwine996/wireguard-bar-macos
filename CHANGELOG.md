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
