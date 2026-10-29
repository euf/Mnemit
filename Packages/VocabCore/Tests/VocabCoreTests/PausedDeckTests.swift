import Foundation
import Testing

@testable import VocabCore

/// A paused deck (`LearningOptions.isPaused`) asks nothing of the day: `DailyProgress.evaluate` and
/// `DayBreakdown` leave it out of the plan, whatever it holds. What was done in it stays done.
extension DailyProgressTests {
    /// `cards` as a deck of the options the other tests use, paused or not.
    func deck(_ cards: [Card], isPaused: Bool = false) throws -> Deck {
        var options = options()
        options.isPaused = isPaused
        return try Deck(learningOptions: options, cards: cards)
    }

    /// The day a progress asks for: everything but the allowances, which have a place for each deck given, and the words
    /// in memory, which a paused deck keeps.
    func figures(_ progress: DailyProgress) -> [AnyHashable] {
        [
            progress.ring, progress.streak, progress.cardsLeft, progress.newCardsLeft, progress.pace, progress.time, progress.roundPlan,
            progress.streakKeptToday,
        ]
    }

    @Test func aPausedDeckIsLeftOutOfTheDaysPlan() throws {
        let active = try deck((0..<20).map { waiting("a\($0)") } + (0..<10).map { fresh("n\($0)") })
        let paused = try deck((0..<30).map { waiting("b\($0)") } + (0..<40).map { fresh("m\($0)") }, isPaused: true)
        let with = evaluate([active, paused])
        let without = evaluate([active])
        #expect(figures(with) == figures(without))
        #expect(with.cardsLeft > 0)
        // Its words are still in memory.
        #expect(with.memory.words > without.memory.words)
        // The decks given keep their places: the paused deck has none of the day's new cards.
        #expect(with.newCardAllowances == without.newCardAllowances + [0])
        #expect(evaluate([paused, active]).newCardAllowances == [0] + without.newCardAllowances)
    }

    @Test func theDaysNewCardsAreSharedOverTheDecksThatTakePart() throws {
        let first = try deck((0..<30).map { fresh("a\($0)") })
        let second = try deck((0..<30).map { fresh("b\($0)") })
        // Five new cards (150 s) from one queue of the words, newest addition first. Words added together go by the
        // place of their deck: the earlier deck takes all five.
        #expect(evaluate([first, second]).newCardAllowances == [5, 0])
        // Words added a study day later come before them, in whichever deck: two such words take two of the five.
        let added = calendar.start(ofDay: today - 59)
        let later = try deck((0..<2).map { Card(id: UUID(), text: CardText(question: "c\($0)", answer: "c", hint: "")!, created: added) })
        #expect(evaluate([first, later]).newCardAllowances == [3, 2])
        #expect(evaluate([later, first]).newCardAllowances == [2, 3])
        let pausedSecond = try deck((0..<30).map { fresh("b\($0)") }, isPaused: true)
        let progress = evaluate([first, pausedSecond])
        #expect(progress.newCardAllowances == [5, 0])
        #expect(progress.ring == DailyRing(done: 0, goal: 5))
        #expect(evaluate([pausedSecond, first]).newCardAllowances == [0, 5])
    }

    @Test func aDayWithOnlyPausedDecksIsADayWithNoDecks() throws {
        let paused = try deck((0..<30).map { waiting("b\($0)") } + (0..<20).map { fresh("m\($0)") }, isPaused: true)
        let progress = evaluate([paused])
        #expect(figures(progress) == figures(evaluate([])))
        #expect(progress.ring == DailyRing(done: 0, goal: 0))
        #expect(progress.cardsLeft == 0)
        #expect(progress.newCardAllowances == [0])
    }

    /// "Study This Deck" on a paused deck is work like any: it fills the ring and keeps the streak, as the cards of Learn 10
    /// New Words do, and leaves the plan of the other decks as it was.
    @Test func whatIsReviewedInAPausedDeckFillsTheRingAndKeepsTheStreak() throws {
        let active = try deck((0..<10).map { waiting("a\($0)") })
        var paused = try deck((0..<10).map { waiting("b\($0)") }, isPaused: true)
        reviewPlan(of: &paused, at: now)
        let progress = evaluate([active, paused])
        #expect(progress.ring == DailyRing(done: 10, goal: 10))
        #expect(progress.streakKeptToday)
        #expect(progress.cardsLeft == 10)
    }

    /// The ring closed over two decks, then one of them paused: the ring stays closed, the streak kept, and the words in
    /// memory stay what they were.
    @Test func pausingADeckTakesNothingFromToday() throws {
        var first = try deck((0..<10).map { waiting("a\($0)") })
        var second = try deck((0..<10).map { waiting("b\($0)") })
        reviewPlan(of: &first, at: now)
        reviewPlan(of: &second, at: now)
        let before = evaluate([first, second])
        #expect(before.ring == DailyRing(done: 20, goal: 20))
        var options = second.learningOptions
        options.isPaused = true
        _ = second.apply(try #require(DeckChange.changingLearningOptions(options, in: second, calendar: calendar)), at: now, calendar: calendar)
        let after = evaluate([first, second])
        #expect(after.ring.done == 20)
        #expect(after.ring.isGoalMet)
        #expect(after.streakKeptToday)
        #expect(after.streak == before.streak)
        #expect(after.memory == before.memory)
    }

    /// On resume the overdue cards of the days of the pause are due like any: the plan holds them all.
    @Test func aResumedDeckBringsItsOverdueCardsBackIntoThePlan() throws {
        let overdue = (0..<30).map { waiting("o\($0)", onDay: today - 10) }
        let paused = try deck(overdue, isPaused: true)
        #expect(evaluate([paused]).cardsLeft == 0)
        let resumed = try deck(overdue)
        #expect(evaluate([resumed]).cardsLeft == 30)
    }

    @Test func theBreakdownLeavesAPausedDeckOutAndKeepsThePlaceOfEachDeck() throws {
        let active = try deck((0..<10).map { waiting("a\($0)") } + (0..<40).map { fresh("n\($0)") })
        let paused = try deck((0..<30).map { waiting("o\($0)", onDay: today - 3) } + (0..<40).map { fresh("m\($0)") }, isPaused: true)
        let (progress, together) = breakdown([paused, active])
        let (_, alone) = breakdown([active])
        #expect(together.plan == alone.plan)
        #expect(together.days == alone.days)
        #expect(together.decks == [DayBreakdown.DeckNewCards(allowance: 0, ceiling: 0, admitted: 0)] + alone.decks)
        #expect(progress.ring.goal == alone.plan.reviewsDue + alone.plan.learning + alone.plan.newAdmitted)
    }
}
