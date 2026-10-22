import Foundation

/// The words of several decks by their `WordKey`, to find the word a card is about in a deck
/// other than the one it goes to. It reads cards and keeps no deck: a word is the cards of one
/// deck that have one key, with the Greek side of the first of them, a recognition card if
/// there is one, to show the learner.
///
/// Advisory: what `match(_:)` finds only sets default ticks and adds lines of text, so an
/// empty index restores the behaviour of one deck alone.
public struct WordIndex: Sendable {
    /// A word of one deck.
    public struct Match: Hashable, Sendable {
        /// The name of the deck, as the learner knows it.
        public var deck: String
        /// The Greek side of the word as that deck asks it, and what it answers.
        public var question: String
        public var answer: String
        /// The cards of the deck that hold the word, recognition first.
        public var cards: [Card.ID]
    }

    /// What the index finds for a word.
    public enum Hit: Hashable, Sendable {
        /// The same word (`WordKey.same(as:)`).
        case same(Match)
        /// A word that would be the same but for accents (`WordKey.looksLike(_:)`).
        case looksLike(Match)
    }

    private var words: [Match] = []
    private var bySame: [String: [Int]] = [:]
    private var byLoose: [String: [Int]] = [:]

    public init() {}

    /// The words of `decks`, each with the name it is known by.
    public init(decks: [(name: String, deck: Deck)]) {
        for (name, deck) in decks {
            add(deck, named: name)
        }
    }

    public var isEmpty: Bool { words.isEmpty }

    /// The number of words.
    public var count: Int { words.count }

    /// Adds the words of `deck`. Cards without a key are left out; a recognition card, or one
    /// without a kind, stands for its word before a production card does.
    public mutating func add(_ deck: Deck, named name: String) {
        var indexOfNote: [String: Int] = [:]
        for card in deck.cards.filter({ $0.kind != .production }) + deck.cards.filter({ $0.kind == .production }) {
            guard let key = WordKey(card: card) else { continue }
            if let index = indexOfNote[key.note] {
                words[index].cards.append(card.id)
                continue
            }
            let index = words.count
            indexOfNote[key.note] = index
            // A production card asks the translation: the word is on its answer's first line, as
            // the rest of an answer is an example.
            let isProduction = card.kind == .production
            let greek = isProduction ? Self.firstLine(card.answer) : card.question
            words.append(Match(deck: name, question: greek, answer: isProduction ? card.question : Self.firstLine(card.answer), cards: [card.id]))
            for string in key.sameKeys {
                bySame[string, default: []].append(index)
            }
            for string in key.looseKeys {
                byLoose[string, default: []].append(index)
            }
        }
    }

    private static func firstLine(_ text: String) -> String {
        CardText.trimmed(String(text.prefix { !$0.isNewline }))
    }

    /// The word of the first deck that is the same as `key`, else the first that looks like it.
    public func match(_ key: WordKey) -> Hit? {
        if let index = key.sameKeys.compactMap({ bySame[$0]?.first }).min() {
            return .same(words[index])
        }
        if let index = key.looseKeys.compactMap({ byLoose[$0]?.first }).min() {
            return .looksLike(words[index])
        }
        return nil
    }

    /// The word `card` is about, `nil` if it has no key.
    public func match(_ card: Card) -> Hit? {
        WordKey(card: card).flatMap(match)
    }
}
