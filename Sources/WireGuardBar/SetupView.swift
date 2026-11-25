import SwiftUI

/// First-run (and after-update) setup: install wireguard-tools, then the root helper.
struct SetupView: View {
    @Environment(TunnelStore.self) private var store
    @State private var working = false
    @State private var failure: String?

    private var toolsDone: Bool { store.setup != .toolsMissing && store.setup != .checking }
    private var helperDone: Bool { store.setup == .ready }

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 44))
                .foregroundStyle(.white.opacity(0.9))
            Text(store.setup == .helperOutdated ? "Update WireGuard Bar's Helper" : "Set Up WireGuard Bar")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 14) {
                step(1, "WireGuard tools", done: toolsDone,
                     detail: "Installed with Homebrew.",
                     action: toolsDone ? nil : ("Install", installTools))
                step(2, store.setup == .helperOutdated ? "Update helper" : "Install helper", done: helperDone,
                     detail: "Lets WireGuard Bar turn tunnels on and off. macOS asks for Touch ID or your password.",
                     action: helperDone || !toolsDone ? nil
                        : (store.setup == .helperOutdated ? "Update" : "Install", installHelper))
            }
            .padding(18)
            .frame(width: 440)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.white.opacity(0.05)))

            if let failure {
                Text(failure)
                    .font(.callout).foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .frame(width: 440)
                    .textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.windowBackground)
    }

    private func step(_ number: Int, _ title: String, done: Bool, detail: String,
                      action: (String, () async -> Void)?) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(done ? Color.green : .white.opacity(0.1)).frame(width: 26, height: 26)
                if done {
                    Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(.black)
                } else {
                    Text("\(number)").font(.callout.weight(.semibold).monospacedDigit())
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title).fontWeight(.semibold)
                Text(detail).font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            if let (label, run) = action {
                if working {
                    ConnectingOrb().frame(width: 76, height: 26)
                } else {
                    Button(label) { Task { await perform(run) } }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                }
            }
        }
    }

    private func perform(_ run: () async -> Void) async {
        working = true
        failure = nil
        await run()
        await store.checkSetup()
        working = false
        if store.setup == .ready { await store.refresh() }
    }

    private func installTools() async {
        do { try await HelperInstaller.installTools() } catch { failure = error.localizedDescription }
    }

    private func installHelper() async {
        do {
            try await HelperInstaller.installHelper()
        } catch is HelperInstaller.Cancelled {
            return
        } catch {
            failure = error.localizedDescription
        }
    }
}
