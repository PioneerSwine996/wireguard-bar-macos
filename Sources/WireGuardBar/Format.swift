import SwiftUI

extension Int64 {
    var byteString: String { ByteCountFormatter.string(fromByteCount: self, countStyle: .binary) }
}

func handshakeString(_ date: Date?) -> String {
    guard let date else { return "Never" }
    let seconds = max(0, Int(Date().timeIntervalSince(date)))
    switch seconds {
    case ..<60: return "\(seconds)s ago"
    case ..<3600: return "\(seconds / 60)m \(seconds % 60)s ago"
    default: return "\(seconds / 3600)h \(seconds % 3600 / 60)m ago"
    }
}

/// Green = connected, orange = up but the server isn't answering, gray = off.
struct StatusDot: View {
    let tunnel: Tunnel
    var body: some View {
        Circle()
            .fill(tunnel.isConnected ? .green : tunnel.isUp ? .orange : .gray)
            .frame(width: 8, height: 8)
    }
}
