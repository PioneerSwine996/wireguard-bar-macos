import Foundation
import Observation

@MainActor @Observable
final class TunnelStore {
    private(set) var tunnels: [Tunnel] = []
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
        do {
            tunnels = Tunnel.parse(status: try await Helper.run("status"))
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    func setEnabled(_ tunnel: Tunnel, _ enabled: Bool) async {
        busy.insert(tunnel.name)
        defer { busy.remove(tunnel.name) }
        do {
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
