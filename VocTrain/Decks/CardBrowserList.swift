import Foundation
import VocabCore

/// The orders of the card browser. Cards that compare equal keep the order of the deck.
enum BrowserSort: String, CaseIterable, Identifiable {
    /// New cards, then by the day they come due, suspended cards last: the order of the
    /// Mac's table.
    case due
    /// The newest first.
    case added
    /// By question, the way the system sorts names: case and accents don't decide.
    case alphabetical
    /// The most difficult first (FSRS difficulty), new cards last.
    case difficulty
    /// The most lapses first, new cards last.
    case lapses

    var id: Self { self }

    var title: String {
        switch self {
        case .due: String(localized: "Due")
        case .added: String(localized: "Added")
        case .alphabetical: String(localized: "A–Z")
        case .difficulty: String(localized: "Difficulty")
        case .lapses: String(localized: "Lapses")
        }
    }

    /// Whether `lhs` goes before `rhs`; the positions in the deck break a tie.
    fileprivate func precedes(_ lhs: (position: Int, card: Card), _ rhs: (position: Int, card: Card)) -> Bool {
        let order: ComparisonResult =
            switch self {
            case .due: Self.compare(dueKey(lhs.card), dueKey(rhs.card))
            case .added: Self.compare(rhs.card.created, lhs.card.created)
            case .alphabetical: lhs.card.question.localizedStandardCompare(rhs.card.question)
            case .difficulty: Self.compare(difficultyKey(rhs.card), difficultyKey(lhs.card))
            case .lapses: Self.compare(rhs.card.learningState?.lapses ?? -1, lhs.card.learningState?.lapses ?? -1)
            }
        return order == .orderedSame ? lhs.position < rhs.position : order == .orderedAscending
    }

    private func dueKey(_ card: Card) -> Double {
        if card.isSuspended { return .infinity }
        return card.learningState?.due.timeIntervalSinceReferenceDate ?? -.infinity
    }

    private func difficultyKey(_ card: Card) -> Double {
        card.learningState?.difficulty ?? -1
    }

    private static func compare<Value: Comparable>(_ lhs: Value, _ rhs: Value) -> ComparisonResult {
        lhs < rhs ? .orderedAscending : lhs > rhs ? .orderedDescending : .orderedSame
    }
}

/// What the card browser shows of a card at its right: when it comes back, or why it
/// doesn't, or that it is new.
enum BrowserState: Equatable {
    case suspended
    case leech
    case new
    case due(Date)

    /// A suspended card says so even if it is a leech: the learner suspended it, or a
    /// session did when it became one, and either way no session asks it. A leech that is
    /// back in the cycle says Leech in place of its date.
    init(_ card: Card, leechThreshold: Int) {
        if card.isSuspended {
            self = .suspended
        } else if card.isLeech(threshold: leechThreshold) {
            self = .leech
        } else if let learningState = card.learningState {
            self = .due(learningState.due)
        } else {
            self = .new
        }
    }

    func text(now: Date) -> String {
        switch self {
        case .suspended: String(localized: "Suspended")
        case .leech: String(localized: "Leech")
        case .new: String(localized: "New")
        case let .due(date): Format.due(date, now: now)
        }
    }

    var symbol: String? {
        switch self {
        case .suspended: "pause.circle"
        case .leech: "exclamationmark.triangle"
        case .new, .due: nil
        }
    }
}

/// What the browser lists: the cards of a deck through a filter, a search and a sort. The
/// filters are `CardFilter` of VocabCore, the Mac's too, and their counts `Deck.filterCounts(at:)`.
enum CardBrowserList {
    /// The cards of `filter`, sorted by `sort`.
    ///
    /// - Parameter positions: The positions in `cards` that a search found, see
    ///   `CardSearchIndex`; `nil` for no search.
    static func shown(
        _ cards: [Card], filter: CardFilter, sort: BrowserSort, positions: Set<Int>? = nil, leechThreshold: Int, now: Date
    ) -> [Card] {
        cards.enumerated()
            .filter { position, card in
                (positions?.contains(position) ?? true) && filter.matches(card, at: now, leechThreshold: leechThreshold)
            }
            .map { (position: $0.offset, card: $0.element) }
            .sorted(by: sort.precedes)
            .map(\.card)
    }
}

/// Keeps what the browser derived from the cards between two renders: the search index and
/// the list. Typing, selecting and scrolling render again and again, and the deck can have
/// thousands of cards; a render that finds the same input gets the same answer.
///
/// Not observable: the view asks for the list while it renders.
@MainActor
final class CardBrowserMemo {
    struct Input: Equatable {
        var deck: Deck
        var filter: CardFilter
        var sort: BrowserSort
        var query: String
        /// The minute the due cards are counted at: a card comes due while the screen is open.
        var minute: Int
    }

    struct Output {
        var rows: [Card]
        var counts: [CardFilter: Int]
    }

    private var input: Input?
    private var output = Output(rows: [], counts: [:])
    private var indexedCards: [Card] = []
    private var index = CardSearchIndex(cards: [])

    func output(deck: Deck, filter: CardFilter, sort: BrowserSort, query: String, now: Date) -> Output {
        let cards = deck.cards
        let next = Input(
            deck: deck, filter: filter, sort: sort, query: query.trimmingCharacters(in: .whitespaces),
            minute: Int(now.timeIntervalSince1970 / 60))
        // Cheap while nothing changed: arrays that share their storage compare equal at once.
        if next == input { return output }
        var positions: Set<Int>?
        if !next.query.isEmpty {
            if cards != indexedCards {
                indexedCards = cards
                index = CardSearchIndex(cards: cards)
            }
            positions = Set(index.positions(matching: next.query))
        }
        output = Output(
            rows: CardBrowserList.shown(
                cards, filter: filter, sort: sort, positions: positions, leechThreshold: deck.learningOptions.leechThreshold, now: now),
            counts: deck.filterCounts(at: now))
        input = next
        return output
    }
}
