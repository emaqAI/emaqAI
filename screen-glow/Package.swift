// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ScreenGlow",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "ScreenGlow",
            path: "Sources/ScreenGlow"
        )
    ]
)
