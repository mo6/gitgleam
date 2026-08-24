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
                .process("Resources"),
                // Copied as a directory so preview.html can load marked/mermaid
                // by relative path. `.process` would flatten/mangle the JS.
                .copy("WebPreview"),
            ]
        ),
        .testTarget(
            name: "GitgleamTests",
            dependencies: ["Gitgleam"],
            path: "Tests/GitgleamTests"
        )
    ]
)
