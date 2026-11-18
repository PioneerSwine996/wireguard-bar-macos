import SwiftUI
import UniformTypeIdentifiers

/// One background for the whole tunnels window: sidebar, toolbar and detail.
extension Color {
    static let windowBackground = Color(white: 0.035)
}

/// Sidebar + detail. The sidebar collapses to a narrow rail of numbered tunnel badges with
/// status lights instead of disappearing (NavigationSplitView can only hide it entirely).
struct MainWindow: View {
    @Environment(TunnelStore.self) private var store
    @State private var selection: String?
    @State private var importing = false
    @AppStorage("sidebarCompact") private var compact = false

    var body: some View {
        HStack(spacing: 0) {
            Group {
                if compact { rail } else { sidebarList }
            }
            .frame(width: compact ? 60 : 220)
            .frame(maxHeight: .infinity, alignment: .top)

            Divider().overlay(.white.opacity(0.06))

            Group {
                if let tunnel = store.tunnels.first(where: { $0.name == selection }) {
                    TunnelDetail(tunnel: tunnel)
                } else {
                    ContentUnavailableView("Select a Tunnel", systemImage: "network")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    withAnimation(.snappy(duration: 0.25)) { compact.toggle() }
                } label: {
                    Image(systemName: "sidebar.left")
                }
                .help(compact ? "Expand Sidebar" : "Collapse Sidebar")
                .keyboardShortcut("s", modifiers: [.command, .control])
            }
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
        .background(Color.windowBackground)
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

    private var sidebarList: some View {
        List(store.tunnels, selection: $selection) { tunnel in
            HStack(spacing: 8) {
                StatusDot(tunnel: tunnel)
                Text(tunnel.name)
            }
            .tag(tunnel.name)
        }
        .scrollContentBackground(.hidden)
        .safeAreaInset(edge: .bottom) {
            HStack { importButton; Spacer() }.padding(10)
        }
        .overlay {
            if store.tunnels.isEmpty {
                ContentUnavailableView("No Tunnels", systemImage: "lock.shield",
                                       description: Text("Import a .conf file with +."))
            }
        }
    }

    /// Collapsed sidebar: tunnels as numbered badges, in sidebar order, each with its status light.
    private var rail: some View {
        VStack(spacing: 10) {
            ForEach(Array(store.tunnels.enumerated()), id: \.element.id) { index, tunnel in
                RailBadge(number: index + 1, tunnel: tunnel, selected: tunnel.name == selection) {
                    selection = tunnel.name
                }
            }
            Spacer()
            importButton.padding(.bottom, 10)
        }
        .padding(.top, 10)
        .frame(maxWidth: .infinity)
    }

    private var importButton: some View {
        Button { importing = true } label: {
            Image(systemName: "plus").font(.body.weight(.medium)).frame(width: 24, height: 24)
        }
        .buttonStyle(.borderless)
        .help("Import a tunnel from a .conf file")
        .accessibilityLabel("Import tunnel")
    }
}

struct RailBadge: View {
    let number: Int
    let tunnel: Tunnel
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("\(number)")
                .font(.system(.body, design: .rounded).weight(.semibold).monospacedDigit())
                .foregroundStyle(selected ? .white : .secondary)
                .frame(width: 36, height: 36)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(selected ? Color.accentColor : Color.white.opacity(0.07)))
                .overlay(alignment: .topTrailing) {
                    StatusDot(tunnel: tunnel)
                        .padding(2)
                        .background(Circle().fill(Color.windowBackground))
                        .offset(x: 4, y: -4)
                }
        }
        .buttonStyle(.plain)
        .help(tunnel.name)
        .accessibilityLabel("\(number). \(tunnel.name)\(tunnel.isUp ? ", connected" : "")")
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
