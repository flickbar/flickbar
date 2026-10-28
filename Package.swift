// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Flickbar",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "FlickbarCore"),
        .executableTarget(name: "Flickbar", dependencies: ["FlickbarCore"]),
        .testTarget(name: "FlickbarCoreTests", dependencies: ["FlickbarCore"]),
    ]
)
