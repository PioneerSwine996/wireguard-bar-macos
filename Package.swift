// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "WireGuardBar",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(name: "WireGuardBar", path: "Sources/WireGuardBar"),
        .testTarget(name: "WireGuardBarTests", dependencies: ["WireGuardBar"], path: "Tests")
    ],
    swiftLanguageModes: [.v5]
)
