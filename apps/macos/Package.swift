// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "HermesAgent",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "HermesAgent", targets: ["HermesAgent"])
    ],
    targets: [
        .executableTarget(
            name: "HermesAgent",
            linkerSettings: [.linkedFramework("Security")]
        ),
        .testTarget(name: "HermesAgentTests", dependencies: ["HermesAgent"])
    ]
)
