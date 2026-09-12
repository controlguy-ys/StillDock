// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "StillDock",
    platforms: [.macOS(.v14)],
    products: [.library(name: "StillDockCore", targets: ["StillDockCore"])],
    targets: [
        .target(name: "StillDockCore", path: "Core"),
        .testTarget(name: "StillDockCoreTests", dependencies: ["StillDockCore"], path: "Tests")
    ],
    swiftLanguageModes: [.v5]
)
