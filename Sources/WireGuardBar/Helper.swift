import Foundation

/// Runs the root helper installed by `scripts/install-helper.sh`, through `sudo -n`.
/// `-n` never prompts: if the sudoers rule is missing the call fails with a clear message.
enum Helper {
    static let path = "/Library/PrivilegedHelperTools/wgbar-helper"

    struct Failure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    static func run(_ args: String..., input: String? = nil) async throws -> String {
        try await Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
            process.arguments = ["-n", path] + args
            let out = Pipe(), err = Pipe(), stdin = Pipe()
            process.standardOutput = out
            process.standardError = err
            process.standardInput = stdin
            try process.run()
            if let input { stdin.fileHandleForWriting.write(Data(input.utf8)) }
            try stdin.fileHandleForWriting.close()
            // ponytail: stdout then stderr read in sequence; fine for the helper's small outputs.
            let output = out.fileHandleForReading.readDataToEndOfFile()
            let errors = err.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                let text = String(decoding: errors, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
                if text.contains("a password is required") || text.contains("command not found") || text.contains("No such file") {
                    throw Failure(message: "The helper isn't installed. Run: sudo ./scripts/install-helper.sh")
                }
                throw Failure(message: text.isEmpty ? "wgbar-helper exited with status \(process.terminationStatus)" : text)
            }
            return String(decoding: output, as: UTF8.self)
        }.value
    }
}
