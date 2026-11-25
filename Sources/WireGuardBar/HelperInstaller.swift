import Foundation

/// What's missing before tunnels can run, checked at launch and after each install step.
enum SetupState: Equatable {
    case checking
    case toolsMissing       // Homebrew's wireguard-tools isn't installed
    case helperMissing      // root helper / sudoers rule not installed
    case helperOutdated     // installed helper is older than this app's copy
    case ready
}

/// Installs the bundled root helper through macOS's administrator prompt (Touch ID or password),
/// and wireguard-tools through Homebrew.
enum HelperInstaller {
    /// Must match HELPER_VERSION in scripts/wgbar-helper (a test keeps them in sync).
    static let expectedVersion = "3"
    static let wgQuick = "/opt/homebrew/bin/wg-quick"
    static let brew = "/opt/homebrew/bin/brew"

    static func check() async -> SetupState {
        guard FileManager.default.isExecutableFile(atPath: wgQuick) else { return .toolsMissing }
        do {
            let version = try await Helper.run("version").trimmingCharacters(in: .whitespacesAndNewlines)
            return version == expectedVersion ? .ready : .helperOutdated
        } catch {
            let message = error.localizedDescription
            return message.contains("isn't installed") ? .helperMissing : .helperOutdated
        }
    }

    struct Cancelled: Error {}

    /// Runs the bundled install-helper.sh as root. macOS shows its standard administrator prompt,
    /// which offers Touch ID where the Mac supports it and the account password otherwise.
    static func installHelper() async throws {
        guard let script = Bundle.main.url(forResource: "install-helper", withExtension: "sh", subdirectory: "Helper") else {
            throw Helper.Failure(message: "This copy of WireGuard Bar is missing its helper files. Re-download the app.")
        }
        let command = "\(shellQuote(script.path)) \(shellQuote(NSUserName()))"
        let appleScript = "do shell script \(appleScriptString(command)) with administrator privileges "
            + "with prompt \(appleScriptString("WireGuard Bar needs to install its helper so it can turn tunnels on and off."))"
        let result = try await run("/usr/bin/osascript", ["-e", appleScript])
        if result.status != 0 {
            if result.errors.contains("-128") { throw Cancelled() }   // user clicked Cancel
            throw Helper.Failure(message: result.errors.isEmpty ? "The helper install failed." : result.errors)
        }
    }

    /// `brew install wireguard-tools`, as the user (Homebrew refuses to run as root).
    static func installTools() async throws {
        guard FileManager.default.isExecutableFile(atPath: brew) else {
            throw Helper.Failure(message: "Homebrew isn't installed. Get it from brew.sh, then try again.")
        }
        let result = try await run(brew, ["install", "wireguard-tools"])
        if result.status != 0 {
            throw Helper.Failure(message: result.errors.isEmpty ? "brew install wireguard-tools failed." : result.errors)
        }
    }

    // MARK: - Plumbing

    private static func run(_ tool: String, _ args: [String]) async throws -> (status: Int32, errors: String) {
        try await Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: tool)
            process.arguments = args
            var env = ProcessInfo.processInfo.environment
            env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
            process.environment = env
            let err = Pipe()
            process.standardOutput = FileHandle.nullDevice
            process.standardError = err
            try process.run()
            let errors = String(decoding: err.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            process.waitUntilExit()
            return (process.terminationStatus, errors.trimmingCharacters(in: .whitespacesAndNewlines))
        }.value
    }

    /// Single-quotes a string for /bin/sh.
    static func shellQuote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// A double-quoted AppleScript string literal.
    static func appleScriptString(_ s: String) -> String {
        "\"" + s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }
}
