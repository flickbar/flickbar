// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Flickbar",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0"),
    ],
    targets: [
        .target(name: "FlickbarCore"),
        .executableTarget(name: "Flickbar", dependencies: ["FlickbarCore", "KeyboardShortcuts"]),
        .testTarget(name: "FlickbarCoreTests", dependencies: ["FlickbarCore"]),
    ]
)
