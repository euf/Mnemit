import Foundation
import VocabCore

/// The decks open in the app, by their files: a deck stays open until it is closed or the app quits, so its undo
/// steps survive a switch to another deck and a study run uses the deck the sidebar shows. The ring on the Mac covers
/// these decks (`DailyRingModel`).
@MainActor
final class OpenDecks {
    static let shared = OpenDecks()

    private var kept: [String: OpenDeck] = [:]
    private var order: [String] = []

    /// The open decks' documents that are read, in the order the decks were opened.
    var documents: [VocabularyDocument] {
        order.compactMap { kept[$0]?.document }
    }

    /// The same file however its URL is spelled.
    static func key(_ url: URL) -> String {
        url.standardizedFileURL.resolvingSymlinksInPath().path
    }

    /// The deck of the file at `url`: the one open already, else a new one. There is one deck
    /// per file: NSDocumentController keeps one document per file.
    func open(_ url: URL) -> OpenDeck {
        let key = Self.key(url)
        if let deck = kept[key] { return deck }
        let deck = OpenDeck(url: url)
        kept[key] = deck
        order.append(key)
        return deck
    }

    /// The kept deck of the file, if there is one.
    func deck(for url: URL) -> OpenDeck? {
        kept[Self.key(url)]
    }

    /// Saves and closes the kept deck of the file, before the file is renamed or deleted. A change whose
    /// undo group is still open is saved too: the deck waits for the group to close first.
    /// A deck whose save failed stays kept, open, with its unsaved changes; returns `false` then.
    @discardableResult
    func close(_ url: URL) async -> Bool {
        let key = Self.key(url)
        guard let deck = kept.removeValue(forKey: key) else { return true }
        order.removeAll { $0 == key }
        await deck.settleChanges()
        guard await deck.close() else {
            kept[key] = deck
            order.append(key)
            return false
        }
        return true
    }

    /// Saves and closes every kept deck, when the app quits. The decks whose save failed stay kept and open;
    /// returns `false` if there are any.
    func closeAll() async -> Bool {
        var failed = false
        let decks = order.compactMap { kept[$0] }
        kept = [:]
        order = []
        for deck in decks {
            await deck.settleChanges()
            if !(await deck.close()) {
                failed = true
                let key = Self.key(deck.url)
                kept[key] = deck
                order.append(key)
            }
        }
        return !failed
    }

    /// The words of the open decks but `document`'s, paused ones included, for the places that
    /// look for the word of a card in another deck (`WordIndex`); built off the main thread. A
    /// deck is named by its file, or by its place among the open ones while it has none.
    func wordIndex(excluding document: VocabularyDocument) async -> WordIndex {
        let decks = documents.enumerated().filter { $0.element !== document }.map { position, other in
            (name: other.packageURL?.deletingPathExtension().lastPathComponent ?? String(localized: "Deck \(position + 1)"), deck: other.deck)
        }
        return await WordIndex.load(decks)
    }
}
