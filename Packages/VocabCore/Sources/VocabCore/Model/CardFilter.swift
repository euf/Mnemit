import Foundation

/// The filters of a card browser, the same on every platform: **All · Due · New ·
/// Learning · Suspended · Leeches**.
///
/// Due, New and Learning list the cards a study session may ask, so a suspended card
/// shows only under Suspended. Leeches are the cards of `Card.isLeech(threshold:)`, suspended
/// or not: a card stays under Leeches after the learner resumes it. The filters overlap: a learning card that is due is both Due and
/// Learning.
public enum CardFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    /// Studied cards whose due date has come, in review or in (re)learning.
    case due
    /// Cards never studied.
    case new
    /// Cards in learning or relearning, due or not.
    case learning
    case suspended
    case leeches

    public var id: String { rawValue }

    /// Whether `card` belongs to the filter at `now`; `leechThreshold` is the deck's
    /// `LearningOptions.leechThreshold`.
    public func matches(_ card: Card, at now: Date, leechThreshold: Int) -> Bool {
        switch self {
        case .all:
            true
        case .due:
            !card.isSuspended && card.learningState.map { $0.due <= now } == true
        case .new:
            !card.isSuspended && card.isNew
        case .learning:
            !card.isSuspended && card.learningState.map { $0.phase != .review } == true
        case .suspended:
            card.isSuspended
        case .leeches:
            card.isLeech(threshold: leechThreshold)
        }
    }
}

extension Deck {
    /// How many cards each filter shows at `now`, in one pass over the cards.
    public func filterCounts(at now: Date) -> [CardFilter: Int] {
        let threshold = learningOptions.leechThreshold
        var counts = Dictionary(uniqueKeysWithValues: CardFilter.allCases.map { ($0, 0) })
        for card in cards {
            for filter in CardFilter.allCases where filter.matches(card, at: now, leechThreshold: threshold) {
                counts[filter, default: 0] += 1
            }
        }
        return counts
    }

    /// The other cards of the word `card` belongs to, in deck order: the cards that share
    /// its `Card.note`. Empty for a card without a note.
    public func siblings(of card: Card) -> [Card] {
        guard let note = card.note else { return [] }
        return cards.filter { $0.note == note && $0.id != card.id }
    }
}
