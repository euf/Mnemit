// swift-tools-version: 6.0

import PackageDescription

// Fork-only tool (euf): builds or extends a .voctrain deck from a TSV/CSV without the
// Mac app's GUI. Lives outside the upstream package so merges from upstream don't touch it.
let package = Package(
    name: "deck-from-tsv",
    platforms: [.macOS(.v14)],
    dependencies: [.package(path: "../../Packages/VocabCore")],
    targets: [
        .executableTarget(name: "deck-from-tsv", dependencies: [.product(name: "VocabCore", package: "VocabCore")])
    ]
)
