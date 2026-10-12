// swift-tools-version:5.9
// Optional: lets SwiftPM-aware editors index the project. The supported
// build is scripts/build-app.sh, which calls swiftc directly.
import PackageDescription

let package = Package(
    name: "Dispose",
    platforms: [.macOS(.v13)],
    targets: [
        // Pure layout model, no AppKit.
        .target(name: "DisposeCore"),
        // The menu-bar app: Accessibility, hotkeys, window tracking.
        .executableTarget(name: "Dispose", dependencies: ["DisposeCore"]),
    ]
)
