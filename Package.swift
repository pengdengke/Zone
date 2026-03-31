// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ZoneCore",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "ZoneCore", targets: ["ZoneCore"])
    ],
    targets: [
        .target(
            name: "ZoneCore",
            path: "Sources/ZoneCore"
        ),
        .testTarget(
            name: "ZoneCoreTests",
            dependencies: ["ZoneCore"],
            path: "Tests/ZoneCoreTests"
        )
    ]
)
