// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "QTube",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "QTube", targets: ["QTube"])
    ],
    targets: [
        .executableTarget(
            name: "QTube",
            path: "Sources/QTube"
        ),
        .testTarget(
            name: "QTubeTests",
            dependencies: ["QTube"],
            path: "Tests/QTubeTests"
        )
    ],
    swiftLanguageModes: [.v5]
)
