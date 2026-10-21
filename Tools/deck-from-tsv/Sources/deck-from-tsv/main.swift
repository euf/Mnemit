import DeckSync
import Foundation

// deck-from-tsv <cards.tsv> <deck.mnemit | deck.voctrain> [--dry-run] [--suspend-missing] [--backup-dir DIR]
//               [--new-per-session N|none] [--new-production-per-session N|none]
//               [--unlock-days N] [--new-order deck|newest]
//
// Syncs a deck with a TSV in place and never loses progress; see `SyncPlan` and
// `SyncOptions.usage`.

func fail(_ message: String, usage: Bool = false) -> Never {
    FileHandle.standardError.write(Data((message + "\n" + (usage ? SyncOptions.usage + "\n" : "")).utf8))
    exit(usage ? 2 : 1)
}

let options: SyncOptions
do {
    options = try SyncOptions.parse(Array(CommandLine.arguments.dropFirst()))
} catch {
    fail("\(error)", usage: true)
}

do {
    print(try SyncRun.run(options))
} catch {
    fail("\(error)")
}
