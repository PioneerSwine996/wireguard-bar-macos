import CoreLocation
import SwiftUI

/// Wi-Fi networks that turn this tunnel on automatically (and off again when you leave them).
struct OnDemandSection: View {
    @Environment(TunnelStore.self) private var store
    let tunnel: String
    @State private var newNetwork = ""

    private var networks: [String] { store.onDemand[tunnel] ?? [] }

    var body: some View {
        Section {
            Toggle("On-Demand", isOn: Binding(
                get: { store.isOnDemandEnabled(tunnel) },
                set: { store.setOnDemandEnabled($0, for: tunnel) }))

            if store.isOnDemandEnabled(tunnel) { networkRows }
        } header: {
            Text("On-Demand")
        }
    }

    @ViewBuilder private var networkRows: some View {
        ForEach(networks, id: \.self) { ssid in
            HStack {
                Label(ssid, systemImage: "wifi")
                Spacer()
                Button { store.removeOnDemand(ssid, from: tunnel) } label: {
                    Image(systemName: "minus.circle.fill")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Remove \(ssid)")
            }
        }

        HStack {
            TextField("Wi-Fi name", text: $newNetwork)
                .textFieldStyle(.roundedBorder)
                .onSubmit(addTyped)
            Button("Add", action: addTyped)
                .disabled(newNetwork.trimmingCharacters(in: .whitespaces).isEmpty)
        }

        currentNetworkRow
    }

    @ViewBuilder private var currentNetworkRow: some View {
        switch store.locationStatus {
        case .notDetermined:
            Button("Allow Location Access to Read the Current Network") { store.requestLocationAccess() }
        case .denied, .restricted:
            Button("Turn On Location Access in System Settings…") {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices")!)
            }
        default:
            if let ssid = store.currentSSID {
                Button("Add Current Network (\(ssid))") { store.addOnDemand(ssid, to: tunnel) }
                    .disabled(networks.contains(ssid))
            } else {
                Text("Not connected to Wi-Fi").foregroundStyle(.secondary)
            }
        }
    }

    private func addTyped() {
        store.addOnDemand(newNetwork, to: tunnel)
        newNetwork = ""
    }
}
