import Foundation
import VocabCore

/// The words of the other decks, for the places that add or show a word: the import preview,
/// the lesson words, the card detail. `WordIndex` is advisory, so a place that has no index shows
/// what it did before.
extension WordIndex {
    /// The index of `decks`, each with the name the learner knows it by, built off the main
    /// thread: every card of every deck is read for its key.
    static func load(_ decks: [(name: String, deck: Deck)]) async -> WordIndex {
        await Task.detached { WordIndex(decks: decks) }.value
    }
}

extension WordIndex.Match {
    /// The word of a card, as another deck has it: «Also in Greek A1–A2: ο/η οδηγός → driver».
    var alsoInLine: String {
        String(localized: "Also in \(deck): \(question) → \(answer)")
    }

    /// A word that differs from this one by an accent only: «Similar to άπλος in Greek A1–A2: simple».
    var similarLine: String {
        String(localized: "Similar to \(question) in \(deck): \(answer)")
    }
}

extension CardImporter.Candidate {
    /// What the other decks say of the card: the same word, or one that differs by an accent;
    /// `nil` for neither.
    var otherDeckLine: String? {
        if case let .inOtherDeck(match)? = duplicate {
            match.alsoInLine
        } else {
            similar?.similarLine
        }
    }
}

extension [CardImporter.Candidate] {
    /// One line per deck that holds the word of some candidates, in the order the decks first
    /// appear: «12 cards are also in Greek A1–A2 and start unticked.»
    var otherDeckSummary: [String] {
        var counts: [(deck: String, count: Int)] = []
        for case let .inOtherDeck(match)? in map(\.duplicate) {
            if let index = counts.firstIndex(where: { $0.deck == match.deck }) {
                counts[index].count += 1
            } else {
                counts.append((match.deck, 1))
            }
        }
        return counts.map { String(localized: "\($0.count) cards are also in \($0.deck) and start unticked.") }
    }
}
