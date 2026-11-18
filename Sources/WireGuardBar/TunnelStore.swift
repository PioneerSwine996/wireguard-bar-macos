import CoreLocation
import CoreWLAN
import Foundation
import Observation

@MainActor @Observable
final class TunnelStore {
    var tunnels: [Tunnel] = []
    private(set) var busy: Set<String> = []
    var error: String?

    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var refreshing = false

    /// Shortest time the loading orb stays up for a connect/disconnect, so it reads as feedback.
    static let minimumBusy: TimeInterval = 1.5

    /// On-demand Wi-Fi names per tunnel name.
    var onDemand: [String: [String]] = UserDefaults.standard.dictionary(forKey: "onDemand") as? [String: [String]] ?? [:] {
        didSet { UserDefaults.standard.set(onDemand, forKey: "onDemand") }
    }
    /// On-Demand switch per tunnel name; the network list is kept while it's off.
    var onDemandEnabled: [String: Bool] = UserDefaults.standard.dictionary(forKey: "onDemandEnabled") as? [String: Bool] ?? [:] {
        didSet { UserDefaults.standard.set(onDemandEnabled, forKey: "onDemandEnabled") }
    }

    /// Defaults to on for tunnels that already have networks, so existing setups keep working.
    func isOnDemandEnabled(_ tunnel: String) -> Bool {
        onDemandEnabled[tunnel] ?? (onDemand[tunnel]?.isEmpty == false)
    }

    func setOnDemandEnabled(_ on: Bool, for tunnel: String) {
        onDemandEnabled[tunnel] = on
        if on {
            lastSSID = nil   // check the current network right away
        } else if autoConnected == tunnel {
            autoConnected = nil   // stays connected; it just won't auto-disconnect
        }
    }

    /// "Route all traffic" per tunnel name. Missing = run the config's own AllowedIPs untouched.
    var routeAll: [String: Bool] = UserDefaults.standard.dictionary(forKey: "routeAll") as? [String: Bool] ?? [:] {
        didSet { UserDefaults.standard.set(routeAll, forKey: "routeAll") }
    }
    /// Current Wi-Fi name; macOS only reveals it to apps with Location access.
    private(set) var currentSSID: String?
    private(set) var locationStatus: CLAuthorizationStatus = .notDetermined
    /// This Mac's IPv4 address on the local network (Wi-Fi/Ethernet), read on-device.
    private(set) var localIP: String?
    @ObservationIgnored private let location = CLLocationManager()
    @ObservationIgnored private var lastSSID: String??   // nil = not read yet
    @ObservationIgnored private var autoConnected: String?   // tunnel that on-demand turned on

    init() {
        Task { await refresh() }
        // ponytail: fixed 3 s poll (one sudo call each); pause while no UI is visible if it ever matters.
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
    }

    func refresh() async {
        guard !refreshing else { return }
        refreshing = true
        appStoreConflict = await Self.connectedAppStoreTunnel()
        do {
            tunnels = Tunnel.parse(status: try await Helper.run("status"))
        } catch {
            self.error = error.localizedDescription
        }
        locationStatus = location.authorizationStatus
        currentSSID = CWWiFiClient.shared().interface()?.ssid()
        localIP = Self.localIPv4()
        refreshing = false
        await applyOnDemand()
    }

    /// Acts only when the Wi-Fi network changes, so a manual connect/disconnect sticks
    /// until the next network change.
    private func applyOnDemand() async {
        guard busy.isEmpty, lastSSID != .some(currentSSID) else { return }
        lastSSID = .some(currentSSID)
        if let ssid = currentSSID,
           let target = tunnels.first(where: { isOnDemandEnabled($0.name) && onDemand[$0.name]?.contains(ssid) == true }) {
            if !target.isUp {
                autoConnected = target.name
                await setEnabled(target, true)
            }
        } else if let name = autoConnected, let tunnel = tunnels.first(where: { $0.name == name }), tunnel.isUp {
            autoConnected = nil
            await setEnabled(tunnel, false)
        }
    }

    /// First up-and-running IPv4 address on an en* interface, preferring en0 (Wi-Fi on most Macs).
    nonisolated static func localIPv4() -> String? {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return nil }
        defer { freeifaddrs(head) }
        let upRunning = UInt32(IFF_UP | IFF_RUNNING)
        var best: (name: String, ip: String)?
        for ifa in sequence(first: first, next: { $0.pointee.ifa_next }).map(\.pointee) {
            guard let addr = ifa.ifa_addr, addr.pointee.sa_family == UInt8(AF_INET),
                  ifa.ifa_flags & upRunning == upRunning else { continue }
            let name = String(cString: ifa.ifa_name)
            guard name.hasPrefix("en") else { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard getnameinfo(addr, socklen_t(addr.pointee.sa_len), &host, socklen_t(host.count),
                              nil, 0, NI_NUMERICHOST) == 0 else { continue }
            if best == nil || name == "en0" { best = (name, String(cString: host)) }
        }
        return best?.ip
    }

    func addOnDemand(_ ssid: String, to tunnel: String) {
        let ssid = ssid.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !ssid.isEmpty, onDemand[tunnel]?.contains(ssid) != true else { return }
        onDemand[tunnel, default: []].append(ssid)
        lastSSID = nil   // re-evaluate against the current network
    }

    func removeOnDemand(_ ssid: String, from tunnel: String) {
        onDemand[tunnel]?.removeAll { $0 == ssid }
        if onDemand[tunnel]?.isEmpty == true { onDemand[tunnel] = nil }
    }

    func requestLocationAccess() {
        location.requestWhenInUseAuthorization()
    }

    /// Name of a tunnel the App Store WireGuard app has connected, if any (from `scutil --nc list`).
    private(set) var appStoreConflict: String?

    nonisolated private static func connectedAppStoreTunnel() async -> String? {
        await Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/scutil")
            process.arguments = ["--nc", "list"]
            let out = Pipe()
            process.standardOutput = out
            process.standardError = FileHandle.nullDevice
            guard (try? process.run()) != nil else { return nil }
            let text = String(decoding: out.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            process.waitUntilExit()
            // e.g. * (Connected)  E0A7…  VPN (com.wireguard.macos) "Home (No-PiHole)"  [VPN:com.wireguard.macos]
            for line in text.split(separator: "\n")
            where line.contains("(Connected)") && line.contains("com.wireguard.macos") {
                let quoted = line.split(separator: "\"")
                if quoted.count >= 2 { return String(quoted[1]) }
            }
            return nil
        }.value
    }

    func setEnabled(_ tunnel: Tunnel, _ enabled: Bool) async {
        // Only one tunnel at a time: turning one on first turns the others off.
        let others = enabled ? tunnels.filter { $0.isUp && $0.name != tunnel.name }.map(\.name) : []
        let involved = Set(others + [tunnel.name])
        busy.formUnion(involved)
        defer { busy.subtract(involved) }
        let started = Date()
        do {
            for name in others {
                _ = try await Helper.run("down", name)
            }
            if enabled {
                _ = try await Helper.run(["up", tunnel.name] + (allowedIPs(for: tunnel.name).map { [$0] } ?? []))
            } else {
                _ = try await Helper.run("down", tunnel.name)
            }
        } catch {
            self.error = error.localizedDescription
        }
        let remaining = Self.minimumBusy - Date().timeIntervalSince(started)
        if remaining > 0 { try? await Task.sleep(for: .seconds(remaining)) }
        await refresh()   // before `busy` clears, so the button flips straight to the new state
    }

    /// AllowedIPs override for the "Route all traffic" toggle, or nil to use the config as written.
    private func allowedIPs(for name: String) async throws -> String? {
        guard let all = routeAll[name] else { return nil }
        if all { return SplitRoutes.all }
        let routes = SplitRoutes.allowedIPs(fromConfigLines: try await Helper.run("addresses", name))
        guard !routes.isEmpty else {
            throw Helper.Failure(message: "\(name) has no Address to build a split tunnel from.")
        }
        return routes
    }

    /// Changes the toggle; a connected tunnel reconnects so the new routes apply.
    func setRouteAll(_ on: Bool, for tunnel: Tunnel) async {
        routeAll[tunnel.name] = on
        guard tunnel.isUp else { return }
        await setEnabled(tunnel, false)
        if let fresh = tunnels.first(where: { $0.name == tunnel.name }) { await setEnabled(fresh, true) }
    }

    func readConfig(_ name: String) async throws -> String {
        try await Helper.run("read", name)
    }

    func writeConfig(_ name: String, _ text: String) async throws {
        _ = try await Helper.run("write", name, input: text)
    }

    /// Copies a .conf file into /etc/wireguard as a new tunnel; returns the tunnel's name.
    func importConfig(from url: URL) async throws -> String {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let text = try String(contentsOf: url, encoding: .utf8)
        guard text.range(of: "[Interface]", options: .caseInsensitive) != nil else {
            throw Helper.Failure(message: "\(url.lastPathComponent) isn't a WireGuard configuration (no [Interface] section).")
        }
        let name = Self.tunnelName(for: url)
        _ = try await Helper.run("import", name, input: text)
        await refresh()
        return name
    }

    /// wg-quick uses the file name as the interface name: 1–15 of [A-Za-z0-9_=+.-].
    /// "Home (No-PiHole).conf" → "Home-No-PiHole".
    nonisolated static func tunnelName(for url: URL) -> String {
        let allowed = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_=+.")
        let base = url.deletingPathExtension().lastPathComponent
        let words = base.split { !allowed.contains($0) }
        let name = String(words.joined(separator: "-").prefix(15))
        return name.isEmpty || name.allSatisfy({ $0 == "." }) ? "tunnel" : name
    }
}
