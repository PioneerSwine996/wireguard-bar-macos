import SwiftUI

/// WireGuard
/// ─────────────
/// Tunnel 1      Connect
/// Tunnel 2   Disconnect
///
/// Manage           Quit
struct MenuBarPanel: View {
    @Environment(TunnelStore.self) private var store
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("WireGuard")
                .font(.headline)
                .padding(.bottom, 10)

            Divider().overlay(.white.opacity(0.15))

            VStack(alignment: .leading, spacing: 10) {
                if store.setup != .ready && store.setup != .checking {
                    Button("Finish Setting Up…") {
                        NSApp.keyWindow?.close()
                        openWindow(id: "main")
                        NSApp.activate()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                } else if store.tunnels.isEmpty && store.error == nil {
                    Text("No tunnels in /etc/wireguard")
                        .font(.caption).foregroundStyle(.secondary)
                }
                ForEach(store.tunnels) { tunnel in
                    MenuTunnelRow(tunnel: tunnel)
                }
                if let conflict = store.appStoreConflict {
                    Notice(text: "The App Store WireGuard app has \"\(conflict)\" connected. Turn it off there.",
                           color: .orange)
                }
                if let error = store.error {
                    Notice(text: error, color: .red)
                        .onTapGesture { store.error = nil }
                }
            }
            .padding(.vertical, 12)

            HStack {
                Button("Manage") {
                    NSApp.keyWindow?.close()   // the menu bar panel; it doesn't close on its own
                    openWindow(id: "main")
                    NSApp.activate()
                }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
            .buttonStyle(.plain)
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(.top, 4)
        }
        .padding(16)
        .frame(width: 264)
        // Fill the whole menu window edge to edge; the system window supplies the rounded corners.
        .background(Color.black.ignoresSafeArea())
        .environment(\.colorScheme, .dark)
    }
}

private struct Notice: View {
    let text: String
    let color: Color
    var body: some View {
        Label(text, systemImage: "exclamationmark.triangle.fill")
            .font(.caption)
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct MenuTunnelRow: View {
    @Environment(TunnelStore.self) private var store
    let tunnel: Tunnel

    var body: some View {
        let busy = store.busy.contains(tunnel.name)
        HStack(spacing: 8) {
            StatusDot(tunnel: tunnel).opacity(tunnel.isUp ? 1 : 0)   // reserve the slot so names align
            Text(tunnel.name)
                .fontWeight(tunnel.isUp ? .semibold : .regular)
                .lineLimit(1)
            Spacer(minLength: 8)
            Button {
                Task { await store.setEnabled(tunnel, !tunnel.isUp) }
            } label: {
                Text(tunnel.isUp ? "Disconnect" : "Connect")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tunnel.isUp ? Color.white.opacity(0.8) : Color.black)
                    .frame(width: 76, height: 22)
                    .background(Capsule().fill(tunnel.isUp ? Color.white.opacity(0.12) : Color.white))
            }
            .buttonStyle(.plain)
            .disabled(busy)
            .opacity(busy ? 0 : 1)   // keeps its space so the row doesn't shift
            .overlay { if busy { ConnectingOrb() } }
            .accessibilityLabel("\(tunnel.isUp ? "Disconnect" : "Connect") \(tunnel.name)")
        }
    }
}
