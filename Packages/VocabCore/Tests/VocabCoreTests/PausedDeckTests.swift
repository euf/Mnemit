import Foundation
import Testing

@testable import VocabCore

/// A paused deck (`LearningOptions.isPaused`) takes no part in the day: `DailyProgress.evaluate` and
/// `DayBreakdown` leave it out, whatever it holds.
extension DailyProgressTests {
    /// `cards` as a deck of the options the other tests use, paused or not.
    func deck(_ cards: [Card], isPaused: Bool = false) throws -> Deck {
        var options = options()
        options.isPaused = isPaused
        return try Deck(learningOptions: options, cards: cards)
    }

    /// Everything a progress holds but the allowances, which have a place for each deck given.
    func figures(_ progress: DailyProgress) -> [AnyHashable] {
        [
            progress.ring, progress.streak, progress.cardsLeft, progress.newCardsLeft, progress.pace, progress.capacity, progress.roundPlan,
            progress.streakKeptToday, progress.memory,
        ]
    }

    @Test func aPausedDeckIsLeftOutOfTheWholeDay() throws {
        let active = try deck((0..<20).map { waiting("a\($0)") } + (0..<10).map { fresh("n\($0)") })
        let paused = try deck((0..<30).map { waiting("b\($0)") } + (0..<40).map { fresh("m\($0)") }, isPaused: true)
        let with = evaluate([active, paused])
        let without = evaluate([active])
        #expect(figures(with) == figures(without))
        #expect(with.cardsLeft > 0)
        // The decks given keep their places: the paused deck has none of the day's new cards.
        #expect(with.newCardAllowances == without.newCardAllowances + [0])
        #expect(evaluate([paused, active]).newCardAllowances == [0] + without.newCardAllowances)
    }

    @Test func theDaysNewCardsAreSharedOverTheDecksThatTakePart() throws {
        let first = try deck((0..<30).map { fresh("a\($0)") })
        let second = try deck((0..<30).map { fresh("b\($0)") })
        // Eight new cards over equal ceilings: four and four.
        #expect(evaluate([first, second]).newCardAllowances == [4, 4])
        let pausedSecond = try deck((0..<30).map { fresh("b\($0)") }, isPaused: true)
        let progress = evaluate([first, pausedSecond])
        #expect(progress.newCardAllowances == [8, 0])
        #expect(progress.ring == DailyRing(done: 0, goal: 8))
        #expect(evaluate([pausedSecond, first]).newCardAllowances == [0, 8])
    }

    @Test func aDayWithOnlyPausedDecksIsADayWithNoDecks() throws {
        let paused = try deck((0..<30).map { waiting("b\($0)") } + (0..<20).map { fresh("m\($0)") }, isPaused: true)
        let progress = evaluate([paused])
        #expect(figures(progress) == figures(evaluate([])))
        #expect(progress.ring == DailyRing(done: 0, goal: 0))
        #expect(progress.cardsLeft == 0)
        #expect(progress.newCardAllowances == [0])
    }

    @Test func whatIsReviewedInAPausedDeckDoesNotFillTheRingOrKeepTheStreak() throws {
        let active = try deck((0..<10).map { waiting("a\($0)") })
        var paused = try deck((0..<10).map { waiting("b\($0)") }, isPaused: true)
        reviewPlan(of: &paused, at: now)
        let progress = evaluate([active, paused])
        #expect(progress.ring == DailyRing(done: 0, goal: 10))
        #expect(progress.streak == Streak(days: 0, repairCards: nil))
        #expect(progress.cardsLeft == 10)
        // The same reviews in the deck once it is active.
        var resumed = paused
        var options = resumed.learningOptions
        options.isPaused = false
        _ = resumed.apply(try #require(DeckChange.changingLearningOptions(options, in: resumed, calendar: calendar)), at: now, calendar: calendar)
        #expect(evaluate([active, resumed]).ring.done == 10)
    }

    /// On resume the overdue cards of the days of the pause are a backlog like any: the plan takes its share.
    @Test func aResumedDeckBringsItsOverdueCardsBackAsABacklog() throws {
        let overdue = (0..<30).map { waiting("o\($0)", onDay: today - 10) }
        let paused = try deck(overdue, isPaused: true)
        #expect(evaluate([paused]).cardsLeft == 0)
        let resumed = try deck(overdue)
        let share = DailyGoal.backlogShare(of: 30, onTime: 0)
        #expect(share < 30)
        #expect(evaluate([resumed]).cardsLeft == share)
    }

    @Test func theBreakdownLeavesAPausedDeckOutAndKeepsThePlaceOfEachDeck() throws {
        let active = try deck((0..<10).map { waiting("a\($0)") } + (0..<40).map { fresh("n\($0)") })
        let paused = try deck((0..<30).map { waiting("o\($0)", onDay: today - 3) } + (0..<40).map { fresh("m\($0)") }, isPaused: true)
        let (progress, together) = breakdown([paused, active])
        let (_, alone) = breakdown([active])
        #expect(together.plan == alone.plan)
        #expect(together.catchUp == alone.catchUp)
        #expect(together.days == alone.days)
        #expect(together.decks == [DayBreakdown.DeckNewCards(allowance: 0, ceiling: 0, admitted: 0)] + alone.decks)
        #expect(progress.ring.goal == alone.plan.reviewsDue + alone.plan.backlogTaken + alone.plan.learning + alone.plan.newAdmitted)
    }
}
