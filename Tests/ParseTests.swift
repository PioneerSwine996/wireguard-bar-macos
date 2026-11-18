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

@Test func importedFileNamesBecomeValidTunnelNames() {
    func name(_ file: String) -> String { TunnelStore.tunnelName(for: URL(fileURLWithPath: "/tmp/" + file)) }
    #expect(name("Home (No-PiHole).conf") == "Home-No-PiHole")
    #expect(name("wg0.conf") == "wg0")
    #expect(name("my office vpn server.conf") == "my-office-vpn-s")
    #expect(name("(((.conf") == "tunnel")
}

@Test func splitTunnelRoutesComeFromAddressAndDNS() {
    let lines = "Address = 192.168.2.3/32, fd17:dd3a:bc90:a64::3/128\nDNS = 192.168.2.1, fd17:dd3a:bc90:a64::1, home.lan\n"
    #expect(SplitRoutes.allowedIPs(fromConfigLines: lines) ==
            "192.168.2.0/24, fd17:dd3a:bc90:a64::/64, 192.168.2.1/32, fd17:dd3a:bc90:a64::1/128")
    #expect(SplitRoutes.allowedIPs(fromConfigLines: "Address = 10.8.0.2/16") == "10.8.0.0/16")
    #expect(SplitRoutes.allowedIPs(fromConfigLines: "Address = 10.8.0.2") == "10.8.0.0/24")
    #expect(SplitRoutes.allowedIPs(fromConfigLines: "DNS = 1.1.1.1\nDNS = 1.1.1.1") == "1.1.1.1/32")
}
