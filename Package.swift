// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Island",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "IslandCore", targets: ["IslandCore"]),
        .executable(name: "Island", targets: ["IslandApp"])
    ],
    targets: [
        .target(name: "IslandCore"),
        .executableTarget(name: "IslandApp", dependencies: ["IslandCore"]),
        .testTarget(name: "IslandCoreTests", dependencies: ["IslandCore"])
    ]
)
