import Foundation
import Testing
@testable import WireGuardBar

@Test func parsesConfigsInterfacesAndPeers() {
    let now = Int(Date().timeIntervalSince1970)
    let status = """
    config\twork
    config\thome
    tunnel\twork\tutun5
    utun5\t(hidden)\tPUB\t51820\toff
    utun5\tPEER\t(hidden)\t1.2.3.4:51820\t0.0.0.0/0\t\(now - 30)\t2048\t1024\t25
    """
    let tunnels = Tunnel.parse(status: status)

    #expect(tunnels.map(\.name) == ["home", "work"])
    #expect(!tunnels[0].isUp)
    let work = tunnels[1]
    #expect(work.interface == "utun5")
    #expect(work.endpoint == "1.2.3.4:51820")
    #expect(work.received == 2048 && work.sent == 1024)
    #expect(work.isConnected)
}

@Test func staleOrMissingHandshakeIsNotConnected() {
    let status = "config\twg0\ntunnel\twg0\tutun3\nutun3\tPEER\t(none)\t(none)\t10.0.0.0/8\t0\t0\t0\toff\n"
    let tunnel = Tunnel.parse(status: status)[0]
    #expect(tunnel.isUp)
    #expect(tunnel.latestHandshake == nil)
    #expect(tunnel.endpoint == nil)
    #expect(!tunnel.isConnected)
}
