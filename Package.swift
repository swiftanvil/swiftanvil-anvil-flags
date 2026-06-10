// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "AnvilFlags",
    platforms: [.iOS(.v18), .macOS(.v15), .tvOS(.v18), .watchOS(.v11), .visionOS(.v2)],
    products: [
        .library(name: "AnvilFlags", targets: ["AnvilFlags"])
    ],
    dependencies: [
        .package(path: "../swiftanvil-anvil-core")
    ],
    targets: [
        .target(name: "AnvilFlags", dependencies: [
            .product(name: "AnvilCore", package: "swiftanvil-anvil-core")
        ]),
        .testTarget(name: "AnvilFlagsTests", dependencies: ["AnvilFlags"])
    ],
    swiftLanguageModes: [.v6]
)
