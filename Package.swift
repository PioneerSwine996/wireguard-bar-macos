// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "WireGuardBar",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(name: "WireGuardBar", path: "Sources/WireGuardBar")
    ],
    swiftLanguageModes: [.v5]
)
