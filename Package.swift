// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "UltimateScrollWM",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "UltimateScrollWM", targets: ["UltimateScrollWM"])
    ],
    targets: [
        .executableTarget(
            name: "UltimateScrollWM",
            path: "Sources/UltimateScrollWM",
            resources: [.copy("Resources")]
        )
    ]
)
