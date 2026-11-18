import SwiftUI

/// A dotted globe with an arc between this Mac and the server. While the tunnel is connected,
/// packets alternate along the arc: green = sending (Mac → server), blue = receiving (server → Mac).
struct TunnelGlobe: View {
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
                           serverLabel: tunnel.endpoint?.components(separatedBy: ":").first ?? "Server")
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
    var t: Double
    /// Packets flow only with a recent handshake.
    var live: Bool
    var up: Bool
    var serverLabel: String

    static let send = Color(red: 0.25, green: 0.95, blue: 0.55)
    static let receive = Color(red: 0.3, green: 0.6, blue: 1.0)

    // ponytail: decorative positions, not real geography (that needs an IP-geolocation lookup).
    private static let peer = unit(lat: 18, lon: -38)
    private static let server = unit(lat: 40, lon: 34)
    private static let lattice = (0..<900).map { OrbWeb.fibDir($0, 900) }
    private static let packetPeriod = 1.8   // seconds per trip

    func draw(in ctx: GraphicsContext, size: CGSize) {
        let r = min(size.width, size.height) * 0.38
        let c = CGPoint(x: size.width / 2, y: size.height / 2)
        // gentle sway that keeps both endpoints on the near side
        let project = OrbWeb.makeProjector(yaw: 0.35 * sin(t * 0.18), tilt: 0.3, cx: c.x, cy: c.y, scale: r)

        // atmosphere
        let glow = Path(ellipseIn: CGRect(x: c.x - r * 1.15, y: c.y - r * 1.15, width: r * 2.3, height: r * 2.3))
        ctx.fill(glow, with: .radialGradient(Gradient(colors: [Color(white: 1, opacity: 0.06), .clear]),
                                             center: c, startRadius: r * 0.8, endRadius: r * 1.15))

        // dotted sphere: dots bucketed by depth, one path + one fill per bucket (far → near),
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

        // arc: great circle lifted off the surface
        let arc = (0...64).map { i -> CGPoint in
            let v = Self.arcPoint(Double(i) / 64)
            let p = project(v.0, v.1, v.2)
            return CGPoint(x: p.0, y: p.1)
        }
        var line = Path()
        line.addLines(arc)
        ctx.stroke(line, with: .color(.white.opacity(up ? 0.9 : 0.25)),
                   style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: up ? [] : [3, 4]))

        if live { drawPacket(in: ctx, project: project) }

        // endpoints + labels
        for (point, label) in [(Self.peer, "This Mac"), (Self.server, serverLabel)] {
            let p = project(point.0, point.1, point.2)
            let at = CGPoint(x: p.0, y: p.1)
            ctx.fill(Path(ellipseIn: CGRect(x: at.x - 9, y: at.y - 9, width: 18, height: 18)),
                     with: .color(.white.opacity(up ? 0.15 : 0.05)))
            ctx.fill(Path(ellipseIn: CGRect(x: at.x - 4, y: at.y - 4, width: 8, height: 8)),
                     with: .color(.white.opacity(up ? 1 : 0.4)))
            ctx.draw(Text(label).font(.caption.weight(.medium)).foregroundStyle(.white.opacity(0.75)),
                     at: CGPoint(x: at.x, y: at.y + 18))
        }
    }

    /// One packet per trip, alternating direction; a fading tail, dimming as it travels.
    private func drawPacket(in ctx: GraphicsContext, project: (Double, Double, Double) -> (Double, Double, Double)) {
        let trip = t / Self.packetPeriod
        let sending = Int(floor(trip)) % 2 == 0
        let phase = trip - floor(trip)
        let eased = phase * phase * (3 - 2 * phase)
        let head = sending ? eased : 1 - eased
        let fade = 1 - 0.75 * phase
        let color = sending ? Self.send : Self.receive

        let tail = 16
        for k in stride(from: tail, through: 0, by: -1) {
            let f = head + (sending ? -1 : 1) * Double(k) * 0.018
            guard (0...1).contains(f) else { continue }
            let v = Self.arcPoint(f)
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

    /// Slerp from peer to server, raised up to 20% above the surface mid-way.
    private static func arcPoint(_ f: Double) -> (Double, Double, Double) {
        let (a, b) = (peer, server)
        let omega = acos(min(1, a.0 * b.0 + a.1 * b.1 + a.2 * b.2))
        let wa = sin((1 - f) * omega) / sin(omega), wb = sin(f * omega) / sin(omega)
        let lift = 1 + 0.2 * sin(.pi * f)
        return ((wa * a.0 + wb * b.0) * lift, (wa * a.1 + wb * b.1) * lift, (wa * a.2 + wb * b.2) * lift)
    }

    private static func unit(lat: Double, lon: Double) -> (Double, Double, Double) {
        let (la, lo) = (lat * .pi / 180, lon * .pi / 180)
        return (cos(la) * sin(lo), sin(la), cos(la) * cos(lo))
    }
}
