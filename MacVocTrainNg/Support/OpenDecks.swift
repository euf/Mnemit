import Foundation
import VocabCore

/// The decks open in the app. Two ways in, until the windows go (phase 5): a window adds its
/// document while it shows it (`add`/`remove`, weak), and `open(_:)` keeps a deck by its file, as
/// the one window will: a deck stays open until it is closed or the app quits, so its undo
/// steps survive a switch to another deck and a study run uses the deck the sidebar shows. The
/// ring on the Mac covers these decks (`DailyRingModel`).
@MainActor
final class OpenDecks {
    static let shared = OpenDecks()

    private struct Entry {
        weak var document: VocabularyDocument?
    }

    private var entries: [Entry] = []
    private var kept: [String: OpenDeck] = [:]
    private var order: [String] = []

    /// The open documents: those of the windows in the order they were added, then those of the
    /// kept decks that are read, in the order they were opened.
    var documents: [VocabularyDocument] {
        let windows = entries.compactMap(\.document)
        return windows + order.compactMap { kept[$0]?.document }.filter { document in !windows.contains { $0 === document } }
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
    func close(_ url: URL) async {
        let key = Self.key(url)
        guard let deck = kept.removeValue(forKey: key) else { return }
        order.removeAll { $0 == key }
        await deck.settleChanges()
        await deck.close()
    }

    /// Saves and closes every kept deck, when the app quits.
    func closeAll() async {
        let decks = order.compactMap { kept[$0] }
        kept = [:]
        order = []
        for deck in decks {
            await deck.settleChanges()
            await deck.close()
        }
    }

    func add(_ document: VocabularyDocument) {
        guard !documents.contains(where: { $0 === document }) else { return }
        entries.append(Entry(document: document))
    }

    func remove(_ document: VocabularyDocument) {
        entries.removeAll { $0.document == nil || $0.document === document }
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
