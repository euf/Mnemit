import Foundation
import VocabCore

/// The documents open in the app, for the daily ring across decks (`DailyRingModel`). A
/// window adds its document while it shows it. Recent documents that are not open are left
/// out: the ring on the Mac covers the decks that are open.
@MainActor
final class OpenDecks {
    static let shared = OpenDecks()

    private struct Entry {
        weak var document: VocabularyDocument?
    }

    private var entries: [Entry] = []

    /// The open documents, in the order they were added.
    var documents: [VocabularyDocument] {
        entries.compactMap(\.document)
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
