import LocalAuthentication
import SwiftUI

/// Warns that the file holds the private key, requires Touch ID (or the login password
/// when Touch ID isn't available), then opens the editor.
struct EditConfigButton: View {
    @Environment(TunnelStore.self) private var store
    let name: String

    @State private var showingWarning = false
    @State private var showingEditor = false
    @State private var text = ""
    @State private var failure: String?

    var body: some View {
        Button("Edit Configuration…", systemImage: "lock.doc") { showingWarning = true }
            .alert("This shows the private key", isPresented: $showingWarning) {
                Button("Authenticate with Touch ID") { Task { await unlock() } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The \(name) configuration contains this device's private key in plain text. Anyone who sees it can impersonate this device on the VPN. Make sure nobody is looking at your screen and you aren't screen sharing or recording.")
            }
            .alert("Couldn't open the configuration", isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(failure ?? "")
            }
            .sheet(isPresented: $showingEditor, onDismiss: { text = "" }) {
                ConfigEditorSheet(name: name, text: $text)
            }
    }

    private func unlock() async {
        do {
            try await LAContext().evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "show the \(name) configuration, including its private key")
            text = try await store.readConfig(name)
            showingEditor = true
        } catch let error as LAError where error.code == .userCancel || error.code == .appCancel {
            return
        } catch {
            failure = error.localizedDescription
        }
    }
}

private struct ConfigEditorSheet: View {
    @Environment(TunnelStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let name: String
    @Binding var text: String
    @State private var saving = false
    @State private var failure: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("/etc/wireguard/\(name).conf").font(.headline.monospaced())
                Spacer()
                Label("Contains private key", systemImage: "key.fill")
                    .font(.caption).foregroundStyle(.orange)
            }
            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .autocorrectionDisabled()
                .frame(minWidth: 560, minHeight: 320)
                .border(.separator)
            if let failure {
                Text(failure).font(.caption).foregroundStyle(.red)
            }
            HStack {
                Text("Changes take effect the next time the tunnel is enabled.")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { Task { await save() } }
                    .keyboardShortcut("s")
                    .buttonStyle(.borderedProminent)
                    .disabled(saving)
            }
        }
        .padding(20)
    }

    private func save() async {
        saving = true
        defer { saving = false }
        do {
            try await store.writeConfig(name, text)
            dismiss()
        } catch {
            failure = error.localizedDescription
        }
    }
}
