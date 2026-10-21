import Foundation
import Testing

@testable import VocabCore

/// Building a deck from its parts, as `DeckFile` and `LegacyImporter` do (#306).
struct DeckTests {
    private let date = Date(timeIntervalSince1970: 1_791_216_000)

    @Test func emptyDeckHasTheDefaultOptions() {
        let deck = Deck()
        #expect(deck.cards.isEmpty)
        #expect(deck.progress.isEmpty)
        #expect(deck.contentModified == nil)
        #expect(deck.learningOptions == LearningOptions())
    }

    @Test func validPartsAreKeptInTheirOrder() throws {
        let cards = [Card(question: "pies", answer: "Hund"), Card(question: "dom", answer: "Haus"), Card(question: "kot", answer: "Katze")]
        var options = LearningOptions()
        options.steps = 3
        let progress = [DailySnapshot(day: 20_000, bins: [3])]

        let deck = try Deck(learningOptions: options, cards: cards, progress: progress, contentModified: date)
        #expect(deck.cards == cards)
        #expect(deck.learningOptions == options)
        #expect(deck.progress == progress)
        #expect(deck.contentModified == date)
    }

    @Test func duplicateCardIDsAreRejected() {
        let dom = Card(question: "dom", answer: "Haus")
        let duplicate = Card(id: dom.id, question: "kot", answer: "Katze")
        #expect(throws: Deck.Error.duplicateCardID(duplicate)) {
            try Deck(cards: [dom, Card(question: "pies", answer: "Hund"), duplicate])
        }
    }

    // MARK: Newest batch

    private func card(_ question: String, created offset: TimeInterval) -> Card {
        Card(question: question, answer: question, created: date.addingTimeInterval(offset))
    }

    @Test func theNewestBatchIsWhatTheLatestRunAdded() throws {
        // Two runs, a lesson each; the second added three cards, in deck order.
        let first = [card("a", created: 0), card("b", created: 0)]
        let second = [card("c", created: 86400), card("d", created: 86400), card("e", created: 86400)]
        let deck = try Deck(cards: [first[0], second[0], first[1], second[1], second[2]])
        #expect(deck.newestBatchIDs == second.map(\.id))
    }

    @Test func theNewestBatchComparesWholeSeconds() throws {
        // `deck.json` keeps whole seconds, a batch just added still holds the fractions.
        let batch = [card("c", created: 86400), card("d", created: 86400.4), card("e", created: 86400.9)]
        let deck = try Deck(cards: [card("a", created: 0), batch[0], batch[1], batch[2], card("older", created: 86399.9)])
        #expect(deck.newestBatchIDs == batch.map(\.id))
    }

    @Test func theNewestBatchLeavesOutSuspendedCards() throws {
        var suspended = card("d", created: 5)
        suspended.isSuspended = true
        let deck = try Deck(cards: [card("a", created: 0), card("c", created: 5), suspended])
        #expect(deck.newestBatchIDs == [deck.cards[1].id])
    }

    @Test func theNewestBatchIgnoresWhatWasStudied() throws {
        var studied = card("c", created: 5)
        studied.learningState = LearningState(phase: .review, stability: 3, difficulty: 5, lastReview: date, due: date, reviews: 3)
        let deck = try Deck(cards: [card("a", created: 0), studied, card("d", created: 5)])
        #expect(deck.newestBatchIDs == [studied.id, deck.cards[2].id])
    }

    @Test func aDeckWithoutCardsHasNoNewestBatch() {
        #expect(Deck().newestBatchIDs.isEmpty)
    }

    @Test func aBatchOfWordsIsPracticedWithoutChangingTheCards() throws {
        let deck = try Deck(cards: [card("a", created: 0), card("b", created: 9), card("c", created: 9)])
        var mode = SessionMode.practice(Practice(practicing: deck.newestBatchIDs, at: date))
        #expect(mode.session.totalCount == 2)
        guard case .practiced? = mode.grade(.good, in: deck, at: date, calendar: .testing) else {
            Issue.record("Practice only counts the review.")
            return
        }
        #expect(mode.session.completedCount == 1)
    }

    /// The same rules as for options set on a deck, `DeckChange.changingLearningOptions`.
    @Test func learningOptionsAreClampedLikeThoseSetOnADeck() throws {
        var options = LearningOptions()
        options.targetRecall = .nan
        options.maximumInterval = 10
        options.steps = 0
        options.cardsPerSession = 0
        options.newCardsPerSession = 100_000

        let built = try Deck(learningOptions: options, cards: [])
        #expect(built.learningOptions.targetRecall == LearningOptions().targetRecall)
        #expect(built.learningOptions.maximumInterval == LearningOptions.maximumIntervalRange.lowerBound)
        #expect(built.learningOptions.steps == LearningOptions.stepsRange.lowerBound)
        #expect(built.learningOptions.cardsPerSession == LearningOptions.sessionLimitRange.lowerBound)
        #expect(built.learningOptions.newCardsPerSession == LearningOptions.sessionLimitRange.upperBound)

        var changed = Deck()
        _ = changed.apply(try #require(DeckChange.changingLearningOptions(options, in: changed, calendar: .testing)), day: 100)
        #expect(built.learningOptions == changed.learningOptions)
    }
}
