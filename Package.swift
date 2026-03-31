// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ZoneCore",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "ZoneCore", targets: ["ZoneCore"])
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-testing.git", revision: "48a471a")
    ],
    targets: [
        .target(
            name: "ZoneCore",
            path: "Sources/ZoneCore"
        ),
        .testTarget(
            name: "ZoneCoreTests",
            dependencies: [
                "ZoneCore",
                .product(name: "Testing", package: "swift-testing")
            ],
            path: "Tests/ZoneCoreTests"
        )
    ]
)
