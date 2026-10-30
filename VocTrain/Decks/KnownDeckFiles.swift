import SwiftUI
import VocabCore

/// The deck files the app knows, for the sheets that add or show a word and look in the other decks
/// for it (`WordIndex`). `StartScreen` puts it in the environment; a view without it, such as a
/// snapshot test, knows no other deck and shows what one deck alone shows.
struct KnownDeckFiles: Sendable {
    var decks: [KnownDeck] = []

    /// The decks the memory model is fitted on besides the one at `url`: every other known deck, paused ones included.
    func pool(excluding url: URL?) -> ReviewPool {
        ReviewPool(files: decks.filter { known in url.map { !KnownDecks.isSameFile(known.url, $0) } ?? true }.map(\.url))
    }

    /// The words of every known deck but the one at `url`, paused decks included, read from
    /// their files off the main thread. ponytail: read again at every sheet; a cache by file
    /// date if the decks grow so that this is slow.
    func wordIndex(excluding url: URL?) async -> WordIndex {
        let others = decks.filter { known in url.map { !KnownDecks.isSameFile(known.url, $0) } ?? true }
        guard !others.isEmpty else { return WordIndex() }
        return await Task.detached(priority: .userInitiated) {
            WordIndex(decks: others.compactMap { known in DeckFileReader.deck(at: known.url).map { (known.name, $0) } })
        }.value
    }
}

extension EnvironmentValues {
    @Entry var knownDeckFiles = KnownDeckFiles()
}
