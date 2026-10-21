import Foundation
import Observation
import VocabCore

/// The search of Today: every card of every known deck, by question, answer, hint and word
/// key, ignoring case and accents.
///
/// Reads the decks from their files, not as documents: no deck is open while Today shows. The
/// cards stay in memory, as light entries with a search index per deck, until the learner is
/// back from a screen that may have changed them (`invalidate()`).
@MainActor @Observable
final class AllCardsSearch {
    /// A card found: where it is and what it says.
    struct Hit: Hashable, Identifiable {
        var deck: KnownDeck
        var card: Card.ID
        var question: String
        var answer: String

        var id: Self { self }
    }

    private struct Entry: Sendable {
        var deck: KnownDeck
        var hits: [Hit]
        var index: CardSearchIndex
    }

    /// `nil` until the decks are read, and again after `invalidate()`.
    private var entries: [Entry]?
    private(set) var isLoading = false
    @ObservationIgnored private var generation = 0

    /// Whether the decks are read, so `hits(for:)` has the answer.
    var isLoaded: Bool { entries != nil }

    /// Forgets what was read: a card may have changed. A read that is under way when this
    /// is called is thrown away, and `load(_:)` reads again.
    func invalidate() {
        generation += 1
        entries = nil
    }

    /// Reads the decks, unless they have been read, off the main actor. A deck that can't be
    /// read leaves no hits.
    func load(_ decks: [KnownDeck]) async {
        while entries == nil {
            guard !isLoading else { return }
            let started = generation
            isLoading = true
            let read = await Task.detached(priority: .userInitiated) {
                decks.compactMap { deck -> Entry? in
                    guard let read = DeckFileReader.deck(at: deck.url) else { return nil }
                    let hits = read.cards.map { Hit(deck: deck, card: $0.id, question: $0.question, answer: $0.answer) }
                    return Entry(deck: deck, hits: hits, index: CardSearchIndex(cards: read.cards))
                }
            }.value
            isLoading = false
            if started == generation {
                entries = read
            }
        }
    }

    /// The cards that match `query`, the decks in the order they were read, the cards in the
    /// order of the deck. Nothing for a blank query.
    func hits(for query: String) -> [Hit] {
        guard let entries, !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        return entries.flatMap { entry in entry.index.positions(matching: query).map { entry.hits[$0] } }
    }
}
