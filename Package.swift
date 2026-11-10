// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Macreply",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Macreply", targets: ["Macreply"])
    ],
    targets: [
        .executableTarget(
            name: "Macreply",
            path: "Sources/Macreply"
        ),
        .testTarget(
            name: "MacreplyTests",
            dependencies: ["Macreply"],
            path: "Tests/MacreplyTests"
        )
    ]
)
