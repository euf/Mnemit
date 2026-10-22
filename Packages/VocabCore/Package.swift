// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "VocabCore",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "VocabCore", targets: ["VocabCore"])
    ],
    dependencies: [
        // Reads the zstd-compressed collection of a current Anki package; Apple's
        // Compression framework has no zstd.
        .package(url: "https://github.com/facebook/zstd", from: "1.5.7")
    ],
    targets: [
        .target(name: "VocabCore", dependencies: [.product(name: "libzstd", package: "zstd")]),
        .testTarget(
            name: "VocabCoreTests",
            dependencies: ["VocabCore", .product(name: "libzstd", package: "zstd")],
            resources: [.copy("Resources")]),
    ]
)
