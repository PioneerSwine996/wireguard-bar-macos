import SwiftUI

/// A dotted globe showing where traffic goes: This Mac → the local network → the VPN server
/// (route all traffic), or forking at the local network into VPN and plain internet (split).
/// Packets: green = sending, blue = receiving through the VPN, gray = traffic outside it.
struct TunnelGlobe: View {
    @Environment(TunnelStore.self) private var store
    let tunnel: Tunnel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var windowVisible = true
    private static let epoch = Date()

    var body: some View {
        // 30 fps is plenty for a slow sway; stop entirely while the window is covered or hidden
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion || !windowVisible)) { context in
            Canvas { ctx, size in
                GlobeScene(t: context.date.timeIntervalSince(Self.epoch),
                           live: tunnel.isConnected,
                           up: tunnel.isUp,
                           routeAll: store.routeAll[tunnel.name] ?? true,
                           serverLabel: tunnel.endpoint?.components(separatedBy: ":").first ?? "Server",
                           networkLabel: [store.currentSSID ?? "Local network", store.localIP]
                               .compactMap { $0 }.joined(separator: "\n"))
                    .draw(in: ctx, size: size)
            }
        }
        .background(WindowVisibilityReader(visible: $windowVisible))
        .accessibilityLabel(tunnel.isConnected ? "Connected to server" : "Not connected")
    }
}

/// Reports whether the hosting window is actually on screen (not covered, minimized or on another Space).
private struct WindowVisibilityReader: NSViewRepresentable {
    @Binding var visible: Bool

    func makeNSView(context: Context) -> ObservingView {
        let view = ObservingView()
        view.onChange = { visible = $0 }
        return view
    }
    func updateNSView(_: ObservingView, context: Context) {}

    final class ObservingView: NSView {
        var onChange: ((Bool) -> Void)?
        private var token: NSObjectProtocol?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let token { NotificationCenter.default.removeObserver(token) }
            guard let window else { return }
            token = NotificationCenter.default.addObserver(
                forName: NSWindow.didChangeOcclusionStateNotification, object: window, queue: .main
            ) { [weak self] _ in self?.report() }
            report()
        }

        private func report() {
            let visible = window?.occlusionState.contains(.visible) ?? false
            DispatchQueue.main.async { self.onChange?(visible) }
        }

        deinit { if let token { NotificationCenter.default.removeObserver(token) } }
    }
}

struct GlobeScene {
    typealias Vec = (Double, Double, Double)

    var t: Double
    /// Packets flow only with a recent handshake.
    var live: Bool
    var up: Bool
    var routeAll: Bool
    var serverLabel: String
    var networkLabel: String

    static let send = Color(red: 0.25, green: 0.95, blue: 0.55)
    static let receive = Color(red: 0.3, green: 0.6, blue: 1.0)
    static let direct = Color(white: 0.72)

    // ponytail: decorative positions, not real geography (that needs an IP-geolocation lookup).
    private static let mac = unit(lat: 2, lon: -46)
    private static let network = unit(lat: 34, lon: -12)
    private static let server = unit(lat: 26, lon: 38)
    private static let internet = unit(lat: -28, lon: 22)
    private static let lattice = (0..<900).map { OrbWeb.fibDir($0, 900) }
    private static let packetPeriod = 1.8   // seconds per trip

    private static let vpnRoute = [mac, network, server]
    private static let directRoute = [mac, network, internet]

    func draw(in ctx: GraphicsContext, size: CGSize) {
        let r = min(size.width, size.height) * 0.36
        let c = CGPoint(x: size.width / 2, y: size.height / 2)
        // gentle sway that keeps every node on the near side
        let project = OrbWeb.makeProjector(yaw: 0.3 * sin(t * 0.18), tilt: 0.3, cx: c.x, cy: c.y, scale: r)

        drawSphere(in: ctx, center: c, radius: r, project: project)

        // links: Mac → network → server always; split mode adds network → internet
        let vpnStyle = StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: up ? [] : [3, 4])
        stroke(Self.vpnRoute, in: ctx, project: project, color: .white.opacity(up ? 0.9 : 0.25), style: vpnStyle)
        if !routeAll {
            stroke([Self.network, Self.internet], in: ctx, project: project,
                   color: Self.direct.opacity(up ? 0.55 : 0.2),
                   style: StrokeStyle(lineWidth: 1.2, lineCap: .round, dash: [2, 5]))
        }

        if live {
            let trip = t / Self.packetPeriod
            let sending = Int(floor(trip)) % 2 == 0
            drawPacket(along: Self.vpnRoute, trip: trip, outbound: sending,
                       color: sending ? Self.send : Self.receive, in: ctx, project: project)
            if !routeAll {
                // traffic that skips the VPN, out of step with the VPN packet
                let other = trip + 0.5
                drawPacket(along: Self.directRoute, trip: other, outbound: Int(floor(other)) % 2 == 0,
                           color: Self.direct, in: ctx, project: project)
            }
        }

        var nodes = [(Self.mac, "This Mac"), (Self.network, networkLabel), (Self.server, serverLabel)]
        if !routeAll { nodes.append((Self.internet, "Internet")) }
        for (point, label) in nodes {
            // the network node's links leave from below it, so its label goes on top
            drawNode(point, label: label, dim: point == Self.internet, above: point == Self.network,
                     in: ctx, project: project)
        }
    }

    private func drawSphere(in ctx: GraphicsContext, center c: CGPoint, radius r: Double,
                            project: (Double, Double, Double) -> Vec) {
        // atmosphere
        let glow = Path(ellipseIn: CGRect(x: c.x - r * 1.15, y: c.y - r * 1.15, width: r * 2.3, height: r * 2.3))
        ctx.fill(glow, with: .radialGradient(Gradient(colors: [Color(white: 1, opacity: 0.06), .clear]),
                                             center: c, startRadius: r * 0.8, endRadius: r * 1.15))

        // dots bucketed by depth, one path + one fill per bucket (far → near),
        // instead of a sort and ~900 separate fills every frame
        let buckets = 8
        var layers = [Path](repeating: Path(), count: buckets)
        for d in Self.lattice {
            let (x, y, z) = project(d.0, d.1, d.2)
            let depth = (z + 1) / 2
            let dr = 0.5 + 1.1 * depth
            layers[min(buckets - 1, Int(depth * Double(buckets)))]
                .addEllipse(in: CGRect(x: x - dr, y: y - dr, width: dr * 2, height: dr * 2))
        }
        for (i, layer) in layers.enumerated() {
            let depth = (Double(i) + 0.5) / Double(buckets)
            ctx.fill(layer, with: .color(Color(white: 0.85, opacity: 0.05 + 0.4 * depth * depth)))
        }
    }

    private func stroke(_ route: [Vec], in ctx: GraphicsContext, project: (Double, Double, Double) -> Vec,
                        color: Color, style: StrokeStyle) {
        var path = Path()
        path.addLines((0...96).map { i in
            let v = Self.point(on: route, Double(i) / 96)
            let p = project(v.0, v.1, v.2)
            return CGPoint(x: p.0, y: p.1)
        })
        ctx.stroke(path, with: .color(color), style: style)
    }

    private func drawNode(_ point: Vec, label: String, dim: Bool, above: Bool, in ctx: GraphicsContext,
                          project: (Double, Double, Double) -> Vec) {
        let p = project(point.0, point.1, point.2)
        let at = CGPoint(x: p.0, y: p.1)
        let strength = (up ? 1 : 0.4) * (dim ? 0.6 : 1)
        ctx.fill(Path(ellipseIn: CGRect(x: at.x - 9, y: at.y - 9, width: 18, height: 18)),
                 with: .color(.white.opacity(0.15 * strength)))
        ctx.fill(Path(ellipseIn: CGRect(x: at.x - 4, y: at.y - 4, width: 8, height: 8)),
                 with: .color(.white.opacity(strength)))
        let lines = Double(label.split(separator: "\n").count)
        ctx.draw(Text(label).font(.caption.weight(.medium)).foregroundStyle(.white.opacity(0.75 * max(strength, 0.6))),
                 at: CGPoint(x: at.x, y: at.y + (above ? -1 : 1) * (12 + 7 * lines)), anchor: .center)
    }

    /// One packet per trip along `route`; a fading tail, dimming as it travels.
    private func drawPacket(along route: [Vec], trip: Double, outbound: Bool, color: Color,
                            in ctx: GraphicsContext, project: (Double, Double, Double) -> Vec) {
        let phase = trip - floor(trip)
        let eased = phase * phase * (3 - 2 * phase)
        let head = outbound ? eased : 1 - eased
        let fade = 1 - 0.75 * phase

        let tail = 16
        for k in stride(from: tail, through: 0, by: -1) {
            let f = head + (outbound ? -1 : 1) * Double(k) * 0.012
            guard (0...1).contains(f) else { continue }
            let v = Self.point(on: route, f)
            let p = project(v.0, v.1, v.2)
            let falloff = 1 - Double(k) / Double(tail + 1)
            let rad = 1.2 + 2.6 * falloff
            ctx.fill(Path(ellipseIn: CGRect(x: p.0 - rad, y: p.1 - rad, width: rad * 2, height: rad * 2)),
                     with: .color(color.opacity(fade * falloff * falloff)))
            if k == 0 {
                ctx.fill(Path(ellipseIn: CGRect(x: p.0 - 10, y: p.1 - 10, width: 20, height: 20)),
                         with: .radialGradient(Gradient(colors: [color.opacity(0.6 * fade), .clear]),
                                               center: CGPoint(x: p.0, y: p.1), startRadius: 0, endRadius: 10))
            }
        }
    }

    /// A point `f` (0…1) of the way along a multi-hop route, each hop an arc lifted off the surface.
    private static func point(on route: [Vec], _ f: Double) -> Vec {
        let hops = Double(route.count - 1)
        let i = min(Int(f * hops), route.count - 2)
        return arc(route[i], route[i + 1], f * hops - Double(i))
    }

    /// Slerp from a to b, raised up to 15% above the surface mid-way.
    private static func arc(_ a: Vec, _ b: Vec, _ f: Double) -> Vec {
        let omega = acos(min(1, a.0 * b.0 + a.1 * b.1 + a.2 * b.2))
        let wa = sin((1 - f) * omega) / sin(omega), wb = sin(f * omega) / sin(omega)
        let lift = 1 + 0.15 * sin(.pi * f)
        return ((wa * a.0 + wb * b.0) * lift, (wa * a.1 + wb * b.1) * lift, (wa * a.2 + wb * b.2) * lift)
    }

    private static func unit(lat: Double, lon: Double) -> Vec {
        let (la, lo) = (lat * .pi / 180, lon * .pi / 180)
        return (cos(la) * sin(lo), sin(la), cos(la) * cos(lo))
    }
}
