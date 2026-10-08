// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LenientMessage",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.library(name: "LenientMessage", targets: ["LenientMessage"])],
    targets: [
        .target(name: "LenientMessage"),
        .testTarget(name: "LenientMessageTests", dependencies: ["LenientMessage"]),
    ]
)
