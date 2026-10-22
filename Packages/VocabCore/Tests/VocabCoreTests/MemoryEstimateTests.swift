import Foundation
import Testing

@testable import VocabCore

/// The words in memory: the sum of the recall probabilities of the learned recognition cards.
struct MemoryEstimateTests {
    let calendar = StudyCalendar.testing
    let today: Int
    let scheduler: Scheduler

    init() {
        today = StudyCalendar.testing.dayNumber(for: Date(timeIntervalSince1970: 1_791_216_000))
        scheduler = Scheduler(learningOptions: LearningOptions(), calendar: .testing)
    }

    /// Noon of the study day `day`; whole study days between two such moments don't depend on daylight saving time.
    func noon(_ day: Int) -> Date { calendar.start(ofDay: day).addingTimeInterval(8 * 3600) }

    func reviewed(_ card: Card, _ grade: Grade = .good, on day: Int) -> Card {
        var random = SeededRandom(seed: 1)
        return scheduler.review(card, grade: grade, at: noon(day), using: &random)
    }

    func recognition(_ question: String = "q", kind: CardKind? = .recognition) -> Card {
        Card(question: question, answer: "a", note: kind == nil ? nil : question, kind: kind)
    }

    func deck(_ cards: [Card]) throws -> Deck { try Deck(cards: cards) }

    func memory(_ cards: [Card], on day: Int) throws -> MemoryEstimate {
        MemoryEstimate(deck: try deck(cards), at: noon(day), calendar: calendar)
    }

    @Test func aNewDeckGivesZero() throws {
        let empty = try memory([], on: today)
        #expect(empty.words == 0)
        #expect(empty.wordsAtDayStart == 0)
        #expect(empty.gainToday == 0)
        #expect(empty.shownWords == 0)
        #expect(empty.nextMilestone == 50)
        #expect(empty.milestoneReachedToday == nil)
        #expect(try memory([recognition("a"), recognition("b")], on: today).words == 0)
    }

    @Test func aCardReviewedGoodJustNowIsOneWord() throws {
        let estimate = try memory([reviewed(recognition(), on: today)], on: today)
        #expect(abs(estimate.words - 1) < 1e-9)
        #expect(estimate.shownWords == 1)
        // The card was new when the day began.
        #expect(estimate.wordsAtDayStart == 0)
        #expect(abs(estimate.gainToday - 1) < 1e-9)
    }

    @Test func theSameCardAMonthLaterIsItsRecallProbability() throws {
        let card = reviewed(recognition(), on: today - 30)
        let stability = try #require(card.learningState).stability
        let expected = FSRS().retrievability(elapsedDays: 30, stability: stability)
        let estimate = try memory([card], on: today)
        #expect(expected < 1)
        #expect(abs(estimate.words - expected) < 1e-9)
        // No review today: the day began with the same words, so the day gains nothing.
        #expect(abs(estimate.gainToday) < 1e-9)
    }

    @Test func productionAndSuspendedCardsAreNotCounted() throws {
        let word = reviewed(recognition("w"), on: today)
        let production = reviewed(recognition("p", kind: .production), on: today)
        var suspended = reviewed(recognition("s"), on: today)
        suspended.suspend(at: noon(today))
        let withoutKind = reviewed(recognition("k", kind: nil), on: today)

        #expect(abs(try memory([word, production, suspended], on: today).words - 1) < 1e-9)
        // A card of an older deck without a kind is a word.
        #expect(abs(try memory([word, production, suspended, withoutKind], on: today).words - 2) < 1e-9)
        // A word with two cards counts once.
        #expect(abs(try memory([word, production], on: today).words - 1) < 1e-9)
    }

    @Test func theDayStartLeavesOutTodaysReviews() throws {
        let first = reviewed(recognition(), on: today - 10)
        let stability = try #require(first.learningState).stability
        let atStart = FSRS().retrievability(elapsedDays: 10, stability: stability)
        let card = reviewed(first, on: today)

        let estimate = try memory([card], on: today)
        #expect(abs(estimate.wordsAtDayStart - atStart) < 1e-9)
        #expect(abs(estimate.words - 1) < 1e-9)
        #expect(abs(estimate.gainToday - (1 - atStart)) < 1e-9)
    }

    @Test func aSuccessfulReviewOfAnOverdueCardGainsWords() throws {
        let card = reviewed(reviewed(recognition(), on: today - 40), on: today)
        let estimate = try memory([card], on: today)
        #expect(estimate.gainToday > 0.1)
        #expect(estimate.words > estimate.wordsAtDayStart)
        // Forgetting it counts as a recall of the state it is in too: the review resets the clock.
        let forgotten = try memory([reviewed(reviewed(recognition(), on: today - 40), .again, on: today)], on: today)
        #expect(forgotten.gainToday >= 0)
    }

    @Test func aCardWithoutAFullLogIsNotReplayedAndGainsNothing() throws {
        var card = recognition()
        card.learningState = LearningState(phase: .review, stability: 10, difficulty: 5, lastReview: noon(today), due: noon(today + 10), reviews: 5)
        let estimate = try memory([card], on: today)
        #expect(abs(estimate.words - 1) < 1e-9)
        #expect(abs(estimate.wordsAtDayStart - 1) < 1e-9)
    }

    @Test func aSuspendedWordIsInNeitherNumber() throws {
        var card = reviewed(recognition(), on: today - 3)
        let before = try memory([card], on: today)
        card.suspend(at: noon(today))
        let after = try memory([card], on: today)
        #expect(before.words > 0)
        #expect(after.words == 0)
        #expect(after.wordsAtDayStart == 0)
    }

    @Test func milestonesAreCrossedWhenTheDayStartsBelowAndNowIsAtOrAbove() {
        #expect(MemoryEstimate.milestones == [50, 100, 250, 500, 1000, 1500, 2000, 3000, 5000])
        #expect(MemoryEstimate(words: 49.9, wordsAtDayStart: 40).nextMilestone == 50)
        #expect(MemoryEstimate(words: 49.9, wordsAtDayStart: 40).milestoneReachedToday == nil)
        #expect(MemoryEstimate(words: 50, wordsAtDayStart: 49.5).milestoneReachedToday == 50)
        #expect(MemoryEstimate(words: 50, wordsAtDayStart: 49.5).nextMilestone == 100)
        // Reached on an earlier day.
        #expect(MemoryEstimate(words: 60, wordsAtDayStart: 50).milestoneReachedToday == nil)
        // An import crosses several: the highest is named.
        #expect(MemoryEstimate(words: 600, wordsAtDayStart: 10).milestoneReachedToday == 500)
        // A fall below a milestone crosses nothing.
        #expect(MemoryEstimate(words: 90, wordsAtDayStart: 110).milestoneReachedToday == nil)
        #expect(MemoryEstimate(words: 5000, wordsAtDayStart: 4990).nextMilestone == nil)
        #expect(MemoryEstimate(words: 5000, wordsAtDayStart: 4990).milestoneReachedToday == 5000)
    }

    @Test func wordsAreShownRoundedDownAndTheGainRounded() {
        #expect(MemoryEstimate(words: 412.99, wordsAtDayStart: 0).shownWords == 412)
        #expect(MemoryEstimate(words: 0.99, wordsAtDayStart: 0).shownWords == 0)
        #expect(MemoryEstimate(words: 12.4, wordsAtDayStart: 10).shownGain == 2)
        #expect(MemoryEstimate(words: 12.6, wordsAtDayStart: 10).shownGain == 3)
        #expect(MemoryEstimate(words: 9.7, wordsAtDayStart: 10).shownGain == 0)
        #expect(MemoryEstimate(words: 8, wordsAtDayStart: 10).shownGain == -2)
    }

    @Test func decksAreSummed() throws {
        let first = try memory([reviewed(recognition("a"), on: today - 5), reviewed(recognition("b"), on: today)], on: today)
        let second = try memory([reviewed(recognition("c"), on: today - 20)], on: today)
        let total = MemoryEstimate.total([first, second])
        #expect(abs(total.words - (first.words + second.words)) < 1e-9)
        #expect(abs(total.wordsAtDayStart - (first.wordsAtDayStart + second.wordsAtDayStart)) < 1e-9)
        #expect(abs(total.gainToday - (first.gainToday + second.gainToday)) < 1e-9)
        #expect(MemoryEstimate.total([]) == MemoryEstimate(words: 0, wordsAtDayStart: 0))
    }

    // MARK: A word in several decks

    func word(_ greek: String, note: String, kind: CardKind? = .recognition) -> Card {
        Card(question: greek, answer: "a", note: note, kind: kind)
    }

    @Test func aWordOfTwoDecksCountsOnceAtTheHighestRecall() throws {
        let weak = reviewed(word("απλός, -ή, -ό", note: "απλός"), on: today - 20)
        let strong = reviewed(word("απλός", note: "απλός"), on: today - 2)
        let first = try memory([weak], on: today)
        let second = try memory([strong], on: today)
        let total = MemoryEstimate.total([first, second])
        #expect(second.words > first.words)
        #expect(abs(total.words - second.words) < 1e-12)
        #expect(abs(total.wordsAtDayStart - second.wordsAtDayStart) < 1e-12)
        // Either order.
        #expect(abs(MemoryEstimate.total([second, first]).words - second.words) < 1e-12)
    }

    @Test func theHighestRecallAtTheDayStartCountsToo() throws {
        // The copy reviewed today was the weaker one when the day began.
        let old = reviewed(word("νερό", note: "νερό#το"), on: today - 5)
        let reviewedToday = reviewed(reviewed(word("νερό", note: "νερό#το"), on: today - 30), on: today)
        let first = try memory([old], on: today)
        let second = try memory([reviewedToday], on: today)
        let total = MemoryEstimate.total([first, second])
        #expect(abs(total.words - 1) < 1e-9)
        #expect(abs(total.wordsAtDayStart - max(first.wordsAtDayStart, second.wordsAtDayStart)) < 1e-12)
        #expect(total.wordsAtDayStart < first.wordsAtDayStart + second.wordsAtDayStart)
    }

    @Test func aCommonGenderArticleJoinsItsTwoGenders() throws {
        let decks = try [
            memory([reviewed(word("ο/η οδηγός", note: "οδηγός#ο/η"), on: today)], on: today),
            memory([reviewed(word("ο οδηγός", note: "οδηγός#ο"), on: today)], on: today),
            memory([reviewed(word("η οδηγός", note: "οδηγός#η"), on: today)], on: today),
        ]
        #expect(abs(MemoryEstimate.total(decks).words - 1) < 1e-9)
        // ο and η alone are two words.
        #expect(abs(MemoryEstimate.total([decks[1], decks[2]]).words - 2) < 1e-9)
    }

    @Test func differentWordsAndCardsWithoutAKeyAreCountedEach() throws {
        let first = try memory(
            [reviewed(word("κύριος", note: "κύριος"), on: today), reviewed(word("πώς", note: "πώς"), on: today), reviewed(recognition("a"), on: today)], on: today)
        let second = try memory(
            [reviewed(word("ο κύριος", note: "κύριος#ο"), on: today), reviewed(word("πως", note: "πως"), on: today), reviewed(recognition("a"), on: today)],
            on: today)
        #expect(abs(MemoryEstimate.total([first, second]).words - 6) < 1e-9)
    }

    @Test func aWordHeldTwiceByOneDeckCountsOnce() throws {
        let one = try memory(
            [reviewed(word("απλός", note: "απλός"), on: today), reviewed(word("απλός, -ή, -ό", note: "απλός"), on: today - 9)], on: today)
        #expect(one.words > 1.2)
        #expect(abs(MemoryEstimate.total([one]).words - 1) < 1e-9)
    }

    @Test func aTotalOfPlainNumbersIsTheirSum() {
        let total = MemoryEstimate.total([MemoryEstimate(words: 1.5, wordsAtDayStart: 1), MemoryEstimate(words: 2, wordsAtDayStart: 0.5)])
        #expect(total == MemoryEstimate(words: 3.5, wordsAtDayStart: 1.5))
    }
}
