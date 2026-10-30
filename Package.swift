// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Flickbar",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.10.1"),
    ],
    targets: [
        .target(name: "FlickbarCore"),
        .executableTarget(name: "Flickbar", dependencies: ["FlickbarCore", "KeyboardShortcuts", "Sparkle"],
                          // Sparkle.framework ships in the app's Contents/Frameworks (see scripts/bundle.sh).
                          linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]),
        .testTarget(name: "FlickbarCoreTests", dependencies: ["FlickbarCore"]),
    ]
)
