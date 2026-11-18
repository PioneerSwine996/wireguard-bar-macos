import LocalAuthentication
import LocalAuthenticationEmbeddedUI
import SwiftUI

/// Opens a sheet that asks for Touch ID inside the window, then becomes the editor.
struct EditConfigButton: View {
    let name: String
    @State private var showingSheet = false

    var body: some View {
        Button("Edit Configuration…", systemImage: "lock.doc") { showingSheet = true }
            .sheet(isPresented: $showingSheet) { ConfigSheet(name: name) }
    }
}

/// Touch ID runs in an embedded `LAAuthenticationView`, so the app never hands focus to a
/// separate system panel (which, once closed, sends focus to whatever app was active before and
/// leaves this window behind it). The config text only lives while the sheet is open.
private struct ConfigSheet: View {
    @Environment(TunnelStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let name: String

    @State private var text: String?
    @State private var failure: String?
    @State private var context = LAContext()

    var body: some View {
        if let unlocked = Binding($text) {
            ConfigEditorSheet(name: name, text: unlocked)
        } else {
            VStack(spacing: 14) {
                TouchIDView(context: context).fixedSize()   // the view draws at its own intrinsic size
                Text("Touch ID to show \(name)").font(.headline)
                Text("The configuration contains this device's private key in plain text. Make sure nobody can see your screen.")
                    .font(.callout).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                if let failure {
                    Text(failure).font(.caption).foregroundStyle(.red)
                }
                Button("Cancel", role: .cancel) { context.invalidate(); dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(28)
            .frame(width: 360)
            .task { await unlock() }
        }
    }

    private func unlock() async {
        // No Touch ID (lid closed, no sensor): the system password panel is the only option, and
        // then focus can still wander — bring the window back as best macOS allows.
        let embedded = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        let window = NSApp.keyWindow
        do {
            try await context.evaluatePolicy(
                embedded ? .deviceOwnerAuthenticationWithBiometrics : .deviceOwnerAuthentication,
                localizedReason: "show the \(name) configuration and its private key")
            if !embedded {
                NSApp.activate()
                window?.orderFrontRegardless()
                window?.makeKey()
            }
            text = try await store.readConfig(name)
        } catch let error as LAError where error.code == .userCancel || error.code == .appCancel || error.code == .systemCancel {
            dismiss()
        } catch {
            failure = error.localizedDescription
        }
    }
}

private struct TouchIDView: NSViewRepresentable {
    let context: LAContext
    func makeNSView(context _: Context) -> LAAuthenticationView {
        LAAuthenticationView(context: context, controlSize: .small)
    }
    func updateNSView(_: LAAuthenticationView, context _: Context) {}
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
