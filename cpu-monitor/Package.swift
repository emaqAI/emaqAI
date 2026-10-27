// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CPUMonitor",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "CPUMonitor",
            path: "Sources/CPUMonitor"
        )
    ]
)
