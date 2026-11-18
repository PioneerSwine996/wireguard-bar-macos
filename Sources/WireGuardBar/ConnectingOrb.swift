// SwiftUI port of the "connecting" thinking orb (mode `web`, 20 px preset) from
// https://github.com/Jakubantalik/thinking-orbs (src/engine/core.ts + web.ts).
// Verified against the repo's golden vectors in Tests/ConnectingOrbTests.swift.
//
// MIT License
//
// Copyright (c) 2026 Jakub Antalik
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import SwiftUI

/// Animated dotted constellation shown while a tunnel is switching on or off.
/// Light dots for dark backgrounds (the menu bar panel is always black).
struct ConnectingOrb: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private static let epoch = Date()

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            Canvas { ctx, size in
                let t = context.date.timeIntervalSince(Self.epoch) * OrbWeb.speed
                OrbWeb.frame(size: size.width, t: t).draw(in: ctx)
            }
        }
        .frame(width: OrbWeb.size, height: OrbWeb.size)
        .accessibilityLabel("Connecting…")
    }
}

struct OrbDot { var x, y, z, r, white, a: Double }
struct OrbLine { var x1, y1, x2, y2, white, a, w: Double }

struct OrbFrame {
    var dots: [OrbDot]
    var lines: [OrbLine]

    /// Lines first so nodes sit on top; dots are already z-sorted far→near.
    /// Dark substrate: ink is mirrored (1 - white) so near dots read bright.
    func draw(in ctx: GraphicsContext) {
        for l in lines {
            var path = Path()
            path.move(to: CGPoint(x: l.x1, y: l.y1))
            path.addLine(to: CGPoint(x: l.x2, y: l.y2))
            ctx.stroke(path, with: .color(Self.ink(l.white, l.a)), lineWidth: l.w)
        }
        for d in dots {
            let rect = CGRect(x: d.x - d.r, y: d.y - d.r, width: d.r * 2, height: d.r * 2)
            ctx.fill(Path(ellipseIn: rect), with: .color(Self.ink(d.white, d.a)))
        }
    }

    private static func ink(_ white: Double, _ alpha: Double) -> Color {
        Color(white: 1 - min(1, max(0, white)), opacity: alpha)
    }
}

/// The `web` mode with the `connecting-20` preset baked in (spec/orbs-golden.json → resolved).
enum OrbWeb {
    static let size: CGFloat = 20
    static let speed = 6.63
    static let nodeN = 8, signals = 1
    static let thr = 0.72, nodeR = 1.4 * 1.52, nodeRDepth = 1.8 * 1.52
    static let lineW = 0.8, rsPow = 0.6, rMin = 0.3

    static func frame(size: Double, t: Double) -> OrbFrame {
        let c = size / 2
        let project = makeProjector(yaw: t * 0.12, tilt: 0.32, cx: c, cy: c, scale: c * 0.8)
        let rs = pow(size / 300, rsPow)

        let nodes: [(Double, Double, Double)] = (0..<nodeN).map { i in
            let d = fibDir(i, nodeN), i = Double(i)
            let x = d.0 + 0.3 * (vnoise(i * 0.31 + 9, t * 0.24) - 0.5) * 2
            let y = d.1 + 0.3 * (vnoise(i * 0.53 + 27, t * 0.21) - 0.5) * 2
            let z = d.2 + 0.3 * (vnoise(i * 0.77 + 55, t * 0.27) - 0.5) * 2
            let l = (x * x + y * y + z * z).squareRoot()
            return (x / l, y / l, z / l)
        }

        var lines: [OrbLine] = []
        for i in 0..<nodeN {
            for j in (i + 1)..<nodeN {
                let (a, b) = (nodes[i], nodes[j])
                let dist = ((a.0 - b.0) * (a.0 - b.0) + (a.1 - b.1) * (a.1 - b.1) + (a.2 - b.2) * (a.2 - b.2)).squareRoot()
                guard dist < thr else { continue }
                let p1 = project(a.0, a.1, a.2), p2 = project(b.0, b.1, b.2)
                let depth = ((p1.2 + p2.2) / 2 + 1) / 2
                lines.append(OrbLine(x1: p1.0, y1: p1.1, x2: p2.0, y2: p2.1, white: 0.42,
                                     a: (1 - dist / thr) * (0.3 + 0.55 * depth), w: max(0.6, lineW * rs)))
            }
        }

        var dots: [OrbDot] = nodes.enumerated().map { i, n in
            let p = project(n.0, n.1, n.2)
            let depth = (p.2 + 1) / 2
            let pulse = 1 + 0.25 * sin(t * 1.4 + Double(i) * 2.7)
            return OrbDot(x: p.0, y: p.1, z: p.2, r: (nodeR + nodeRDepth * depth) * pulse * rs,
                          white: 0.55 - 0.45 * depth, a: 1)
        }

        // signals: bright packets running between randomly re-picked node pairs
        for s in 0..<signals {
            let s = Double(s)
            let seg = floor(t * 0.55 + s * 7.31)
            let a = Int(floor(hashD(seg, s * 3.1 + 1.7) * Double(nodeN)))
            let b = Int(floor(hashD(seg, s * 5.7 + 4.2) * Double(nodeN)))
            guard a != b else { continue }
            let f = frac(t * 0.55 + s * 7.31)
            let x = lerp(nodes[a].0, nodes[b].0, f), y = lerp(nodes[a].1, nodes[b].1, f), z = lerp(nodes[a].2, nodes[b].2, f)
            let l = max(1e-6, (x * x + y * y + z * z).squareRoot())
            let p = project(x / l, y / l, z / l)
            let depth = (p.2 + 1) / 2
            dots.append(OrbDot(x: p.0, y: p.1, z: p.2, r: (nodeR * 1.5 + nodeRDepth * depth) * rs,
                               white: 0.05, a: 0.5 + 0.5 * depth))
        }

        // finalizeFrame: drop invisible marks, clamp radii, z-sort far→near
        dots = dots.filter { $0.a >= 0.02 }.map { var d = $0; d.r = max(rMin, d.r); return d }
        dots.sort { $0.z < $1.z }
        return OrbFrame(dots: dots, lines: lines.filter { $0.a >= 0.02 })
    }

    // MARK: core.ts primitives

    private static func makeProjector(yaw: Double, tilt: Double, cx: Double, cy: Double, scale: Double)
        -> (Double, Double, Double) -> (Double, Double, Double) {
        let (st, ct, sy, cyw) = (sin(tilt), cos(tilt), sin(yaw), cos(yaw))
        return { x, y, z in
            let x1 = x * cyw + z * sy
            let z1 = -x * sy + z * cyw
            let y1 = y * ct - z1 * st
            let z2 = y * st + z1 * ct
            return (cx + x1 * scale, cy - y1 * scale, z2)
        }
    }

    private static func fibDir(_ i: Int, _ n: Int) -> (Double, Double, Double) {
        let golden = Double.pi * (3 - 5.0.squareRoot())
        let y = 1 - 2 * (Double(i) + 0.5) / Double(n)
        let rad = (1 - y * y).squareRoot()
        let a = Double(i) * golden
        return (rad * cos(a), y, rad * sin(a))
    }

    private static func vnoise(_ x: Double, _ y: Double) -> Double {
        let xi = floor(x), yi = floor(y)
        var fx = x - xi, fy = y - yi
        fx = fx * fx * (3 - 2 * fx)
        fy = fy * fy * (3 - 2 * fy)
        let a = hashD(xi, yi), b = hashD(xi + 1, yi), c = hashD(xi, yi + 1), d = hashD(xi + 1, yi + 1)
        return a + (b - a) * fx + (c - a) * fy + (a - b - c + d) * fx * fy
    }

    private static func hashD(_ a: Double, _ b: Double) -> Double {
        let h = sin(a * 12.9898 + b * 78.233) * 43758.5453
        return h - floor(h)
    }

    private static func frac(_ x: Double) -> Double { x - floor(x) }
    private static func lerp(_ a: Double, _ b: Double, _ f: Double) -> Double { a + (b - a) * f }
}
