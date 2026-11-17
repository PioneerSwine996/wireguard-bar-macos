import Foundation

struct Peer: Hashable {
    var endpoint: String?
    var latestHandshake: Date?
    var received: Int64
    var sent: Int64
}

struct Tunnel: Identifiable, Hashable {
    let name: String
    /// The utun interface while the tunnel is up.
    var interface: String?
    var peers: [Peer] = []

    var id: String { name }
    var isUp: Bool { interface != nil }
    var received: Int64 { peers.reduce(0) { $0 + $1.received } }
    var sent: Int64 { peers.reduce(0) { $0 + $1.sent } }
    var latestHandshake: Date? { peers.compactMap(\.latestHandshake).max() }
    var endpoint: String? { peers.lazy.compactMap(\.endpoint).first }

    /// WireGuard re-handshakes every 2 minutes while traffic flows, so a handshake in the
    /// last 3 minutes means the server is answering.
    var isConnected: Bool {
        guard isUp, let handshake = latestHandshake else { return false }
        return Date().timeIntervalSince(handshake) < 180
    }

    /// Parses `wgbar-helper status`: `config<TAB>name`, `tunnel<TAB>name<TAB>utunN`,
    /// and `wg show all dump` lines (9 fields = a peer).
    static func parse(status: String) -> [Tunnel] {
        var names: [String] = []
        var interfaceByName: [String: String] = [:]
        var peersByInterface: [String: [Peer]] = [:]

        for line in status.split(separator: "\n") {
            let f = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            switch (f.first, f.count) {
            case ("config", 2):
                names.append(f[1])
            case ("tunnel", 3):
                interfaceByName[f[1]] = f[2]
            case (_, 9):
                let handshake = TimeInterval(f[5]) ?? 0
                peersByInterface[f[0], default: []].append(Peer(
                    endpoint: f[3] == "(none)" ? nil : f[3],
                    latestHandshake: handshake > 0 ? Date(timeIntervalSince1970: handshake) : nil,
                    received: Int64(f[6]) ?? 0,
                    sent: Int64(f[7]) ?? 0))
            default:
                continue
            }
        }

        return names.sorted().map { name in
            let interface = interfaceByName[name]
            return Tunnel(name: name, interface: interface, peers: interface.flatMap { peersByInterface[$0] } ?? [])
        }
    }
}
