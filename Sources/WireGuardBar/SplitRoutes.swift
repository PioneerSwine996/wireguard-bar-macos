import Darwin

/// AllowedIPs for the "Route all traffic" toggle.
enum SplitRoutes {
    static let all = "0.0.0.0/0, ::/0"

    /// Split tunnel: only the tunnel's own networks (from `Address`) plus its DNS servers.
    /// Host addresses are widened to their usual LAN size (/32 → /24, /128 → /64), since a
    /// WireGuard address is often written as a single host.
    /// "Address = 192.168.2.3/32" + "DNS = 192.168.2.1" → "192.168.2.0/24, 192.168.2.1/32".
    static func allowedIPs(fromConfigLines text: String) -> String {
        var routes: [String] = []
        for line in text.split(separator: "\n") {
            let parts = line.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2 else { continue }
            let isDNS = parts[0].lowercased() == "dns"
            for item in parts[1].split(separator: ",") {
                let item = item.trimmingCharacters(in: .whitespaces)
                let route = isDNS ? hostRoute(item) : network(item)
                if let route, !routes.contains(route) { routes.append(route) }
            }
        }
        return routes.joined(separator: ", ")
    }

    private static func hostRoute(_ ip: String) -> String? {
        if parse4(ip) != nil { return "\(ip)/32" }
        if parse6(ip) != nil { return "\(ip)/128" }
        return nil   // DNS search domains aren't addresses
    }

    private static func network(_ cidr: String) -> String? {
        let pieces = cidr.split(separator: "/", maxSplits: 1).map(String.init)
        let given = pieces.count == 2 ? Int(pieces[1]) : nil
        if var bytes = parse4(pieces[0]) {
            let prefix = min(given.map { $0 == 32 ? 24 : $0 } ?? 24, 32)
            mask(&bytes, prefix)
            return "\(format4(bytes))/\(prefix)"
        }
        if var bytes = parse6(pieces[0]) {
            let prefix = min(given.map { $0 == 128 ? 64 : $0 } ?? 64, 128)
            mask(&bytes, prefix)
            return "\(format6(bytes))/\(prefix)"
        }
        return nil
    }

    private static func mask(_ bytes: inout [UInt8], _ prefix: Int) {
        for i in bytes.indices {
            let bits = max(0, min(8, prefix - i * 8))
            bytes[i] &= bits == 0 ? 0 : UInt8(truncatingIfNeeded: 0xFF << (8 - bits))
        }
    }

    private static func parse4(_ s: String) -> [UInt8]? {
        var addr = in_addr()
        guard inet_pton(AF_INET, s, &addr) == 1 else { return nil }
        return withUnsafeBytes(of: &addr) { Array($0) }
    }

    private static func parse6(_ s: String) -> [UInt8]? {
        var addr = in6_addr()
        guard inet_pton(AF_INET6, s, &addr) == 1 else { return nil }
        return withUnsafeBytes(of: &addr) { Array($0) }
    }

    private static func format4(_ b: [UInt8]) -> String { b.map(String.init).joined(separator: ".") }

    private static func format6(_ b: [UInt8]) -> String {
        var addr = in6_addr()
        withUnsafeMutableBytes(of: &addr) { $0.copyBytes(from: b) }
        var out = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
        inet_ntop(AF_INET6, &addr, &out, socklen_t(out.count))
        return String(cString: out)
    }
}
