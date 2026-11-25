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
            MenuBarLabel(icon: Self.menuBarIcon(for: store))
                .environment(store)
        }
        .menuBarExtraStyle(.window)
    }

    /// Off: crossed-out shield. On: locked shield, or unlocked when the active tunnel
    /// isn't routing all traffic (split tunnel).
    private static func menuBarIcon(for store: TunnelStore) -> NSImage {
        guard let active = store.tunnels.first(where: \.isUp) else { return menuBarSymbol("shield.slash") }
        return store.routeAll[active.name] == false ? unlockedShield : menuBarSymbol("lock.shield.fill")
    }

    /// SF Symbols has no unlocked shield, so cut an open lock out of a filled shield,
    /// the same way lock.shield.fill is drawn.
    private static let unlockedShield: NSImage = {
        let shield = menuBarSymbol("shield.fill")
        guard let lock = NSImage(systemSymbolName: "lock.open.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 7.5, weight: .bold)) else { return shield }
        let image = NSImage(size: shield.size, flipped: false) { rect in
            shield.draw(in: rect)
            let lockRect = NSRect(x: rect.midX - lock.size.width / 2 + 0.6, y: rect.midY - lock.size.height / 2 - 0.3,
                                  width: lock.size.width, height: lock.size.height)
            lock.draw(in: lockRect, from: .zero, operation: .destinationOut, fraction: 1)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "WireGuard, split tunnel"
        return image
    }()

    /// MenuBarExtra ignores `.font` on its label, so size the symbol as an NSImage.
    /// Template so the menu bar still tints it for light/dark.
    private static func menuBarSymbol(_ name: String) -> NSImage {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: "WireGuard")?
            .withSymbolConfiguration(.init(pointSize: 16, weight: .regular)) ?? NSImage()
        image.isTemplate = true
        return image
    }
}

/// The menu bar icon. It's the one view that exists from launch, so it also opens the setup
/// window the first time the app finds something missing (new install or outdated helper).
private struct MenuBarLabel: View {
    @Environment(TunnelStore.self) private var store
    @Environment(\.openWindow) private var openWindow
    let icon: NSImage

    var body: some View {
        Image(nsImage: icon)
            .onChange(of: store.setup) { old, new in
                if old == .checking && new != .ready {
                    openWindow(id: "main")
                    NSApp.activate()
                }
            }
    }
}
