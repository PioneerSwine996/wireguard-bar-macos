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
            Image(nsImage: Self.menuBarSymbol(store.tunnels.contains(where: \.isUp) ? "lock.shield.fill" : "shield.slash"))
        }
        .menuBarExtraStyle(.window)
    }

    /// MenuBarExtra ignores `.font` on its label, so size the symbol as an NSImage.
    /// Template so the menu bar still tints it for light/dark.
    private static func menuBarSymbol(_ name: String) -> NSImage {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: "WireGuard")?
            .withSymbolConfiguration(.init(pointSize: 16, weight: .regular)) ?? NSImage()
        image.isTemplate = true
        return image
    }
}
