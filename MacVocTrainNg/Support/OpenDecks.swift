import Foundation

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
}
