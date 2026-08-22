// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Gitgleam",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "Gitgleam",
            path: "Sources/Gitgleam",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "GitgleamTests",
            dependencies: ["Gitgleam"],
            path: "Tests/GitgleamTests"
        )
    ]
)
