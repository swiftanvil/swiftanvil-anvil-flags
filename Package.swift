// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "AnvilFlags",
    platforms: [.iOS(.v16), .macOS(.v13), .tvOS(.v16), .watchOS(.v9), .visionOS(.v1)],
    products: [
        .library(name: "AnvilFlags", targets: ["AnvilFlags"]),
    ],
    targets: [
        .target(name: "AnvilFlags"),
        .testTarget(name: "AnvilFlagsTests", dependencies: ["AnvilFlags"]),
    ],
    swiftLanguageModes: [.v6]
)
