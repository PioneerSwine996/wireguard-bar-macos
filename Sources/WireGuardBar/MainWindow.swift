import SwiftUI

struct MainWindow: View {
    @Environment(TunnelStore.self) private var store
    @State private var selection: String?

    var body: some View {
        NavigationSplitView {
            List(store.tunnels, selection: $selection) { tunnel in
                HStack(spacing: 8) {
                    StatusDot(tunnel: tunnel)
                    Text(tunnel.name)
                }
                .tag(tunnel.name)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 210)
            .overlay {
                if store.tunnels.isEmpty {
                    ContentUnavailableView("No Tunnels", systemImage: "lock.shield",
                                           description: Text("Put .conf files in /etc/wireguard."))
                }
            }
        } detail: {
            if let tunnel = store.tunnels.first(where: { $0.name == selection }) {
                TunnelDetail(tunnel: tunnel)
            } else {
                ContentUnavailableView("Select a Tunnel", systemImage: "network")
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let error = store.error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.white)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.red.opacity(0.85))
                    .onTapGesture { store.error = nil }
            }
        }
        .onChange(of: store.tunnels.map(\.name), initial: true) { _, names in
            // First open (or the selected tunnel vanished): prefer a tunnel that's on.
            if selection == nil || !names.contains(selection!) {
                selection = store.tunnels.first(where: \.isUp)?.name ?? names.first
            }
        }
    }
}

struct TunnelDetail: View {
    @Environment(TunnelStore.self) private var store
    let tunnel: Tunnel

    var body: some View {
        Form {
            Section {
                Toggle("Enabled", isOn: Binding(
                    get: { tunnel.isUp },
                    set: { on in Task { await store.setEnabled(tunnel, on) } }))
                    .disabled(store.busy.contains(tunnel.name))

                LabeledContent("Connected to server") {
                    HStack(spacing: 6) {
                        StatusDot(tunnel: tunnel)
                        Text(!tunnel.isUp ? "No" : tunnel.isConnected ? "Yes" : "No recent handshake")
                    }
                }
                LabeledContent("Data sent", value: tunnel.isUp ? tunnel.sent.byteString : "—")
                LabeledContent("Data received", value: tunnel.isUp ? tunnel.received.byteString : "—")
                LabeledContent("Latest handshake", value: tunnel.isUp ? handshakeString(tunnel.latestHandshake) : "—")
            } header: {
                Text(tunnel.name).font(.title2.bold())
            }

            Section("Details") {
                LabeledContent("Endpoint", value: tunnel.endpoint ?? "—")
            }

            Section {
                EditConfigButton(name: tunnel.name)
            }
        }
        .formStyle(.grouped)
    }
}
