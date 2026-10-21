import Foundation
import Testing

@testable import VocabCore

/// The filters of the card browser, **All · Due · New · Learning · Suspended · Difficult**.
struct CardFilterTests {
    /// 2026-10-05 18:00 in Berlin.
    let now = Date(timeIntervalSince1970: 1_791_216_000)

    func card(_ question: String, phase: LearningPhase? = nil, dueIn: TimeInterval = -3600, lapses: Int = 0, isSuspended: Bool = false, note: String? = nil) -> Card {
        let state = phase.map {
            LearningState(phase: $0, stability: 10, difficulty: 5, lastReview: now.addingTimeInterval(-10 * 86400), due: now.addingTimeInterval(dueIn), reviews: lapses + 3, lapses: lapses)
        }
        var card = Card(question: question, answer: "x", note: note, learningState: state)
        card.isSuspended = isSuspended
        return card
    }

    func matching(_ filter: CardFilter, in cards: [Card], threshold: Int = 8) -> [String] {
        cards.filter { filter.matches($0, at: now, leechThreshold: threshold) }.map(\.question)
    }

    @Test func theFiltersAreNamedAndOrderedLikeTheSpec() {
        #expect(CardFilter.allCases.map(\.rawValue) == ["all", "due", "new", "learning", "suspended", "difficult"])
    }

    @Test func allMatchesEveryCard() {
        let cards = [card("a"), card("b", phase: .review), card("c", isSuspended: true)]
        #expect(matching(.all, in: cards) == ["a", "b", "c"])
    }

    /// Due is a studied card whose date has come; a new card is not due in the browser, and a
    /// card due later is not either.
    @Test func dueIsAStudiedCardWhoseDateHasCome() {
        let cards = [
            card("new"),
            card("overdue", phase: .review, dueIn: -86400),
            card("now", phase: .review, dueIn: 0),
            card("later", phase: .review, dueIn: 3600),
            card("relearning", phase: .relearning, dueIn: -60),
        ]
        #expect(matching(.due, in: cards) == ["overdue", "now", "relearning"])
    }

    @Test func newIsACardNeverStudied() {
        let cards = [card("new"), card("studied", phase: .review), card("learning", phase: .learning)]
        #expect(matching(.new, in: cards) == ["new"])
    }

    @Test func learningIsLearningAndRelearningDueOrNot() {
        let cards = [
            card("new"),
            card("learning", phase: .learning, dueIn: 600),
            card("relearning", phase: .relearning, dueIn: -600),
            card("review", phase: .review),
        ]
        #expect(matching(.learning, in: cards) == ["learning", "relearning"])
    }

    @Test func suspendedCardsShowOnlyUnderSuspendedAndDifficult() {
        let cards = [
            card("new", isSuspended: true),
            card("due", phase: .review, isSuspended: true),
            card("learning", phase: .learning, isSuspended: true),
            card("leech", phase: .review, lapses: 8, isSuspended: true),
            card("active"),
        ]
        #expect(matching(.suspended, in: cards) == ["new", "due", "learning", "leech"])
        #expect(matching(.due, in: cards).isEmpty)
        #expect(matching(.new, in: cards) == ["active"])
        #expect(matching(.learning, in: cards).isEmpty)
        #expect(matching(.difficult, in: cards) == ["leech"])
    }

    /// Difficult is the leech of `Card.isLeech(threshold:)`, resumed or not.
    @Test func difficultFollowsTheLeechThreshold() {
        let cards = [card("seven", phase: .review, lapses: 7), card("eight", phase: .review, lapses: 8), card("ten", phase: .relearning, lapses: 10), card("new")]
        #expect(matching(.difficult, in: cards) == ["eight", "ten"])
        #expect(matching(.difficult, in: cards, threshold: 5) == ["seven", "eight", "ten"])
        #expect(matching(.difficult, in: cards, threshold: 0).isEmpty)
    }

    @Test func countsComeInOnePassAndMatchTheFilters() throws {
        var options = LearningOptions()
        options.leechThreshold = 8
        let cards = [
            card("new"),
            card("new suspended", isSuspended: true),
            card("due", phase: .review, dueIn: -60),
            card("later", phase: .review, dueIn: 86400),
            card("learning", phase: .learning, dueIn: -60),
            card("leech", phase: .review, dueIn: -60, lapses: 9, isSuspended: true),
        ]
        let deck = try Deck(learningOptions: options, cards: cards)
        let counts = deck.filterCounts(at: now)
        for filter in CardFilter.allCases {
            #expect(counts[filter] == matching(filter, in: cards).count, "\(filter)")
        }
        #expect(counts[.all] == 6)
        #expect(counts[.due] == 2)
        #expect(counts[.new] == 1)
        #expect(counts[.learning] == 1)
        #expect(counts[.suspended] == 2)
        #expect(counts[.difficult] == 1)
    }

    @Test func anEmptyDeckCountsZeroForEveryFilter() {
        let counts = Deck().filterCounts(at: now)
        #expect(counts.count == CardFilter.allCases.count)
        #expect(counts.values.allSatisfy { $0 == 0 })
    }

    // MARK: Siblings

    @Test func siblingsShareTheWordKey() throws {
        let recognition = card("αγαπώ", note: "αγαπώ")
        let production = card("lieben", note: "αγαπώ")
        let other = card("σπίτι", note: "σπίτι")
        let alone = card("Katze")
        let deck = try Deck(cards: [recognition, other, production, alone])
        #expect(deck.siblings(of: recognition).map(\.id) == [production.id])
        #expect(deck.siblings(of: production).map(\.id) == [recognition.id])
        #expect(deck.siblings(of: other).isEmpty)
        #expect(deck.siblings(of: alone).isEmpty)
    }
}
