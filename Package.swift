// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ClearDesk",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ClearDeskCore",
            targets: ["ClearDeskCore"]
        ),
        .executable(
            name: "ClearDeskApp",
            targets: ["ClearDeskApp"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "ClearDeskCore",
            dependencies: [],
            path: "Sources/ClearDeskCore"
        ),
        .executableTarget(
            name: "ClearDeskApp",
            dependencies: ["ClearDeskCore"],
            path: "Sources/ClearDeskApp"
        ),
        .testTarget(
            name: "ClearDeskCoreTests",
            dependencies: ["ClearDeskCore"],
            path: "Tests/ClearDeskCoreTests"
        )
    ]
)
