// swift-tools-version: 6.0

import PackageDescription

// Fork-only tool (euf): syncs a .voctrain deck with a TSV of word cards without the Mac
// app's GUI, never losing progress. Lives outside the upstream package so merges from
// upstream don't touch it.
let package = Package(
    name: "deck-from-tsv",
    platforms: [.macOS(.v14)],
    dependencies: [.package(path: "../../Packages/VocabCore")],
    targets: [
        .target(name: "DeckSync", dependencies: [.product(name: "VocabCore", package: "VocabCore")]),
        .executableTarget(name: "deck-from-tsv", dependencies: ["DeckSync"]),
        .testTarget(name: "DeckSyncTests", dependencies: ["DeckSync", .product(name: "VocabCore", package: "VocabCore")]),
    ]
)
