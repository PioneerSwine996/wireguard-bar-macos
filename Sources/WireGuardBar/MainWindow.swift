import SwiftUI
import UniformTypeIdentifiers

/// One background for the whole tunnels window: sidebar, toolbar and detail.
extension Color {
    static let windowBackground = Color(white: 0.035)
}

struct MainWindow: View {
    @Environment(TunnelStore.self) private var store
    @State private var selection: String?
    @State private var importing = false

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
            .scrollContentBackground(.hidden)
            .background(Color.windowBackground)
            .safeAreaInset(edge: .bottom) {
                HStack {
                    Button { importing = true } label: {
                        Image(systemName: "plus").font(.body.weight(.medium)).frame(width: 24, height: 24)
                    }
                    .buttonStyle(.borderless)
                    .help("Import a tunnel from a .conf file")
                    .accessibilityLabel("Import tunnel")
                    Spacer()
                }
                .padding(10)
            }
            .fileImporter(isPresented: $importing,
                          allowedContentTypes: [UTType(filenameExtension: "conf") ?? .data, .plainText]) { result in
                Task {
                    do {
                        selection = try await store.importConfig(from: result.get())
                    } catch {
                        store.error = error.localizedDescription
                    }
                }
            }
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
        .preferredColorScheme(.dark)
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .containerBackground(Color.windowBackground, for: .window)
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
        VStack(spacing: 0) {
            TunnelGlobe(tunnel: tunnel)
                .frame(height: 300)
            overview
        }
        .background(Color.windowBackground)
    }

    private var overview: some View {
        Form {
            Section {
                Toggle("Enabled", isOn: Binding(
                    get: { tunnel.isUp },
                    set: { on in Task { await store.setEnabled(tunnel, on) } }))
                    .disabled(store.busy.contains(tunnel.name))

                Toggle("Route all traffic", isOn: Binding(
                    get: { store.routeAll[tunnel.name] ?? true },
                    set: { on in Task { await store.setRouteAll(on, for: tunnel) } }))
                .disabled(store.busy.contains(tunnel.name))

                LabeledContent("Connected to server") {
                    HStack(spacing: 6) {
                        StatusDot(tunnel: tunnel)
                        Text(!tunnel.isUp ? "No" : tunnel.isConnected ? "Yes" : "No recent handshake")
                    }
                }
                LabeledContent("Data sent") {
                    TrafficValue(text: tunnel.isUp ? tunnel.sent.byteString : "—", color: GlobeScene.send)
                }
                LabeledContent("Data received") {
                    TrafficValue(text: tunnel.isUp ? tunnel.received.byteString : "—", color: GlobeScene.receive)
                }
                LabeledContent("Latest handshake", value: tunnel.isUp ? handshakeString(tunnel.latestHandshake) : "—")
                LabeledContent("Endpoint", value: tunnel.endpoint ?? "—")
            } header: {
                Text(tunnel.name).font(.title2.bold())
            }

            OnDemandSection(tunnel: tunnel.name)

            Section {
                EditConfigButton(name: tunnel.name)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}

/// A value with the globe's packet colour beside it (green = sent, blue = received).
private struct TrafficValue: View {
    let text: String
    let color: Color
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(text)
        }
    }
}
