import SwiftUI

struct MenuBarPanel: View {
    @Environment(TunnelStore.self) private var store
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("WireGuard").font(.headline)
                Spacer()
                let active = store.tunnels.filter(\.isUp).count
                Text("\(active) active").font(.caption).foregroundStyle(.secondary)
            }

            Divider().overlay(.white.opacity(0.15))

            if store.tunnels.isEmpty {
                Text(store.error ?? "No tunnels in /etc/wireguard")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(store.tunnels) { tunnel in
                MenuTunnelRow(tunnel: tunnel)
            }

            Divider().overlay(.white.opacity(0.15))

            HStack {
                Button("Manage Tunnels…") {
                    openWindow(id: "main")
                    NSApp.activate()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(width: 320)
        .background(.black, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(8)
        .environment(\.colorScheme, .dark)
    }
}

private struct MenuTunnelRow: View {
    @Environment(TunnelStore.self) private var store
    let tunnel: Tunnel

    var body: some View {
        HStack(spacing: 10) {
            StatusDot(tunnel: tunnel)
            VStack(alignment: .leading, spacing: 2) {
                Text(tunnel.name).fontWeight(.medium)
                Text(summary)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Toggle(tunnel.name, isOn: Binding(
                get: { tunnel.isUp },
                set: { on in Task { await store.setEnabled(tunnel, on) } }))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .disabled(store.busy.contains(tunnel.name))
        }
    }

    private var summary: String {
        guard tunnel.isUp else { return "Inactive" }
        let traffic = "↓ \(tunnel.received.byteString)  ↑ \(tunnel.sent.byteString)"
        return tunnel.isConnected
            ? "\(traffic) · \(handshakeString(tunnel.latestHandshake))"
            : "No handshake · \(tunnel.endpoint ?? "no endpoint")"
    }
}
