import Foundation
import Observation

@MainActor @Observable
final class TunnelStore {
    var tunnels: [Tunnel] = []
    private(set) var busy: Set<String> = []
    var error: String?

    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var refreshing = false

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
        defer { refreshing = false }
        appStoreConflict = await Self.connectedAppStoreTunnel()
        do {
            tunnels = Tunnel.parse(status: try await Helper.run("status"))
        } catch {
            self.error = error.localizedDescription
        }
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
        do {
            for name in others {
                _ = try await Helper.run("down", name)
            }
            _ = try await Helper.run(enabled ? "up" : "down", tunnel.name)
        } catch {
            self.error = error.localizedDescription
        }
        await refresh()
    }

    func readConfig(_ name: String) async throws -> String {
        try await Helper.run("read", name)
    }

    func writeConfig(_ name: String, _ text: String) async throws {
        _ = try await Helper.run("write", name, input: text)
    }
}
