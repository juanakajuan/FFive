// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FFiveCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "FFiveCore", targets: ["FFiveCore"])
    ],
    targets: [
        .target(name: "FFiveCore"),
        .executableTarget(name: "PerfProbe", dependencies: ["FFiveCore"]),
        .executableTarget(name: "ChangelogGen", dependencies: ["FFiveCore"]),
        .testTarget(name: "FFiveCoreTests", dependencies: ["FFiveCore", "ChangelogGen"]),
    ]
)
