// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "AppShellKit",
    platforms: [.iOS(.v26)],
    products: [
        .library(name: "AppShellKit", targets: ["AppShellKit"]),
    ],
    targets: [
        // UI navigation lives on the main actor; plain data types opt out with `nonisolated`.
        .target(
            name: "AppShellKit",
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .testTarget(
            name: "AppShellKitTests",
            dependencies: ["AppShellKit"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
    ]
)
