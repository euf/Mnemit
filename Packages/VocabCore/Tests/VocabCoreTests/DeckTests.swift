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

    @Test func theNewestBatchIsWhatTheLatestDayAdded() throws {
        // Two days, a lesson each; the second added three cards, in deck order.
        let first = [card("a", created: 0), card("b", created: 0)]
        let second = [card("c", created: 86400), card("d", created: 86400), card("e", created: 86400)]
        let deck = try Deck(cards: [first[0], second[0], first[1], second[1], second[2]])
        #expect(deck.newestBatchIDs(calendar: .testing) == second.map(\.id))
    }

    @Test func cardsAddedLaterTheSameDayJoinTheBatch() throws {
        // A run, then two words typed in by hand the same evening.
        let batch = [card("c", created: 86400), card("d", created: 86400.4), card("e", created: 86400 + 3600)]
        let deck = try Deck(cards: [card("a", created: 0), batch[0], batch[1], batch[2]])
        #expect(deck.newestBatchIDs(calendar: .testing) == batch.map(\.id))
    }

    @Test func theNewestBatchLeavesOutSuspendedCards() throws {
        var suspended = card("d", created: 5)
        suspended.isSuspended = true
        let deck = try Deck(cards: [card("a", created: -86400), card("c", created: 5), suspended])
        #expect(deck.newestBatchIDs(calendar: .testing) == [deck.cards[1].id])
    }

    @Test func theNewestBatchIgnoresWhatWasStudied() throws {
        var studied = card("c", created: 5)
        studied.learningState = LearningState(phase: .review, stability: 3, difficulty: 5, lastReview: date, due: date, reviews: 3)
        let deck = try Deck(cards: [card("a", created: -86400), studied, card("d", created: 5)])
        #expect(deck.newestBatchIDs(calendar: .testing) == [studied.id, deck.cards[2].id])
    }

    @Test func renewingMovesNewCardsIntoTodaysAdditionInTheOrderGiven() throws {
        var studied = card("studied", created: 0)
        studied.learningState = LearningState(phase: .review, stability: 3, difficulty: 5, lastReview: date, due: date, reviews: 3)
        var suspended = card("suspended", created: 0)
        suspended.isSuspended = true
        var deck = try Deck(cards: [card("a", created: 0), card("b", created: 0), card("c", created: 0), studied, suspended])
        let now = date.addingTimeInterval(86400 + 0.7)
        let ids = deck.cards.map(\.id)
        let change = try #require(DeckChange.renewing([ids[2], ids[0], ids[3], ids[4], ids[0]], in: deck, at: now))
        let inverse = deck.apply(change, at: now, calendar: .testing)
        // c, then a: a second apart, ending at `now` in whole seconds; the studied and the suspended card stay.
        #expect(deck.cards[2].created == Date(timeIntervalSince1970: (now.timeIntervalSince1970 - 1).rounded(.down)))
        #expect(deck.cards[0].created == Date(timeIntervalSince1970: now.timeIntervalSince1970.rounded(.down)))
        #expect(deck.cards[1].created == date)
        #expect(deck.cards[3].created == date && deck.cards[4].created == date)
        #expect(deck.newestBatchIDs(calendar: .testing) == [ids[0], ids[2]])
        // A merge takes the new stamps along with the content.
        #expect(deck.cards[0].contentChanged != nil)
        _ = deck.apply(inverse, at: now, calendar: .testing)
        #expect(deck.cards.allSatisfy { $0.created == date })
        #expect(DeckChange.renewing([ids[3], ids[4]], in: deck, at: now) == nil)
    }

    @Test func aLessonAddsItsNewWordsAndRenewsThoseTheDeckHoldsInOneChange() throws {
        var deck = try Deck(cards: [card("known", created: 0)])
        let now = date.addingTimeInterval(86400)
        let added = Card(question: "new", answer: "new", created: now)
        let change = try #require(DeckChange.adding([added], to: deck, renewing: [deck.cards[0].id], at: now))
        let inverse = deck.apply(change, at: now, calendar: .testing)
        #expect(deck.cards.map(\.question) == ["known", "new"])
        #expect(deck.newestBatchIDs(calendar: .testing).count == 2)
        _ = deck.apply(inverse, at: now, calendar: .testing)
        #expect(deck.cards.map(\.question) == ["known"])
        #expect(deck.cards[0].created == date)
    }

    @Test func aDeckWithoutCardsHasNoNewestBatch() {
        #expect(Deck().newestBatchIDs(calendar: .testing).isEmpty)
    }

    @Test func aBatchOfWordsIsPracticedWithoutChangingTheCards() throws {
        let deck = try Deck(cards: [card("a", created: -86400), card("b", created: 9), card("c", created: 9)])
        var mode = SessionMode.practice(Practice(practicing: deck.newestBatchIDs(calendar: .testing), at: date))
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
        options.newCardsPerSession = 100_000

        let built = try Deck(learningOptions: options, cards: [])
        #expect(built.learningOptions.targetRecall == LearningOptions().targetRecall)
        #expect(built.learningOptions.maximumInterval == LearningOptions.maximumIntervalRange.lowerBound)
        #expect(built.learningOptions.steps == LearningOptions.stepsRange.lowerBound)
        #expect(built.learningOptions.newCardsPerSession == LearningOptions.sessionLimitRange.upperBound)
        options.newCardsPerSession = 0
        #expect(try Deck(learningOptions: options, cards: []).learningOptions.newCardsPerSession == 0)
        options.newCardsPerSession = -3
        #expect(try Deck(learningOptions: options, cards: []).learningOptions.newCardsPerSession == LearningOptions.sessionLimitRange.lowerBound)
        options.newCardsPerSession = 100_000

        var changed = Deck()
        _ = changed.apply(try #require(DeckChange.changingLearningOptions(options, in: changed, calendar: .testing)), day: 100)
        #expect(built.learningOptions == changed.learningOptions)
    }
}
