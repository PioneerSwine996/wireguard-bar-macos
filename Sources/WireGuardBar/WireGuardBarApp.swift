import SwiftUI

@main
struct WireGuardBarApp: App {
    @State private var store = TunnelStore()

    var body: some Scene {
        Window("WireGuard Tunnels", id: "main") {
            MainWindow()
                .environment(store)
                .frame(minWidth: 660, minHeight: 720)
        }
        .defaultLaunchBehavior(.suppressed)

        MenuBarExtra {
            MenuBarPanel().environment(store)
        } label: {
            Image(systemName: store.tunnels.contains(where: \.isUp) ? "lock.shield.fill" : "shield.slash")
        }
        .menuBarExtraStyle(.window)
    }
}
