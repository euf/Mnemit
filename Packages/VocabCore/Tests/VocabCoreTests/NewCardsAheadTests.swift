import Foundation
import Testing

@testable import VocabCore

/// Today's new cards look a week ahead: no more than the next week can take (`DailyGoal.newCardsAllowedAhead`), as
/// well as no more than the day's time admits.
extension DailyProgressTests {
    /// `count` review cards due over the seven study days after today, as evenly as they go. Reviewed ten days ago, so
    /// that none of them was reviewed today, which would count as a card done.
    func dueNextWeek(_ count: Int) -> [Card] {
        (0..<count).map { index in
            let due = calendar.start(ofDay: today + 1 + index % NewCardLoad.horizonDays)
            let state = LearningState(phase: .review, stability: 30, difficulty: 5, lastReview: calendar.start(ofDay: today - 10), due: due, reviews: 1)
            return Card(question: "w\(index)", answer: "w", learningState: state)
        }
    }

    var loadPerNewCard: Double { NewCardLoad.reviewsPerDay(addingNewCards: 1, options: options(), at: now, calendar: calendar) }

    @Test func theAheadBoundIsTheMostCardsThatFitTheDay() {
        let pace = Pace(newCard: 30, otherCard: 10)
        // Ten minutes are 60 reviews of 10 s a day: 300 due over a week are 42.9 a day, and 17.1 reviews of room at
        // half a review a day per new card are 34 cards.
        #expect(DailyGoal.newCardsAllowedAhead(seconds: 600, dueAhead: 300, loadPerNewCard: 0.5, pace: pace) == 34)
        // 600 due over a week are 85.7 a day: more than the day has time for.
        #expect(DailyGoal.newCardsAllowedAhead(seconds: 600, dueAhead: 600, loadPerNewCard: 0.5, pace: pace) == 0)
        // 420 due are 60 a day: the day is full, and a card is held back until room for it is left: two cards take a
        // review a day, which 413 due leave.
        #expect(DailyGoal.newCardsAllowedAhead(seconds: 600, dueAhead: 420, loadPerNewCard: 0.5, pace: pace) == 0)
        #expect(DailyGoal.newCardsAllowedAhead(seconds: 600, dueAhead: 417, loadPerNewCard: 0.5, pace: pace) == 0)
        #expect(DailyGoal.newCardsAllowedAhead(seconds: 600, dueAhead: 416, loadPerNewCard: 0.5, pace: pace) == 1)
        #expect(DailyGoal.newCardsAllowedAhead(seconds: 600, dueAhead: 413, loadPerNewCard: 0.5, pace: pace) == 2)
        // A card that adds no reviews is held by nothing, until the reviews due alone don't fit.
        #expect(DailyGoal.newCardsAllowedAhead(seconds: 600, dueAhead: 0, loadPerNewCard: 0, pace: pace) == Int.max)
        #expect(DailyGoal.newCardsAllowedAhead(seconds: 600, dueAhead: 600, loadPerNewCard: 0, pace: pace) == 0)
    }

    @Test func aNewLearnerGetsTheAllowanceOfTheDaysTime() throws {
        let deck = try Deck(learningOptions: options(), cards: (0..<20).map { fresh("n\($0)") })
        let progress = evaluate([deck])
        // 240 s are eight new cards of 30 s, and the week ahead holds nothing.
        #expect(progress.newCardAllowances == [8])
        #expect(progress.newCardLimit == .time)
        #expect(progress.nextWeekSeconds == 0)
    }

    @Test func aHeavyNextWeekAdmitsNoNewCards() throws {
        // 300 reviews due over the week are 43 a day, 429 s of the 240 the day has.
        let deck = try Deck(learningOptions: options(), cards: dueNextWeek(300) + (0..<20).map { fresh("n\($0)") })
        let progress = evaluate([deck])
        #expect(progress.time == 240)
        #expect(progress.newCardAllowances == [0])
        #expect(progress.newCardLimit == .nextWeek)
        #expect(progress.nextWeekSeconds.map { abs($0 - 300.0 / 7 * 10) < 1e-9 } == true)
        // The day's time alone would admit eight.
        #expect(DailyGoal.newCardsAllowed(seconds: progress.time, otherCards: 0, pace: progress.pace) == 8)
    }

    /// At 240 s and 10 s an other card the week holds 168 reviews, and a new card adds one to it (0.14 a day): 163
    /// due leave room for five cards, the day's time for eight.
    @Test func aModerateNextWeekAdmitsFewerThanTheTimeDoesAndMoreThanNone() throws {
        let due = 163
        let deck = try Deck(learningOptions: options(), cards: dueNextWeek(due) + (0..<20).map { fresh("n\($0)") })
        let progress = evaluate([deck])
        let expected = Int(((240.0 / 10 - Double(due) / 7) / loadPerNewCard + 1e-9).rounded(.down))
        #expect(expected == 5)
        #expect(progress.newCardAllowances == [expected])
        #expect(progress.newCardLimit == .nextWeek)
        // The day's time alone would admit eight.
        #expect(DailyGoal.newCardsAllowed(seconds: progress.time, otherCards: 0, pace: progress.pace) == 8)
        // The goal is the cards that are admitted.
        #expect(progress.ring.goal == expected)
    }

    @Test func aNextWeekThatLeavesRoomLeavesTheDaysTimeTheBound() throws {
        // 35 reviews a week are 5 a day: 50 s of 240, and the room is worth more than the eight cards of the day.
        let deck = try Deck(learningOptions: options(), cards: dueNextWeek(35) + (0..<20).map { fresh("n\($0)") })
        let progress = evaluate([deck])
        #expect(progress.newCardAllowances == [8])
        #expect(progress.newCardLimit == .time)
    }

    @Test func theLimitsOfTheDeckStillCapTheAllowance() throws {
        func week(_ options: LearningOptions) throws -> Deck { try Deck(learningOptions: options, cards: dueNextWeek(163) + (0..<20).map { fresh("n\($0)") }) }
        let free = evaluate([try week(options())]).newCardAllowances[0]
        // Room for a few cards ahead, and a ceiling of two below it.
        var limited = options()
        limited.newCardsPerSession = 2
        #expect(free > 2 && free < 8)
        #expect(evaluate([try week(limited)]).newCardAllowances == [2])
        // Free of reviews ahead, the day's time would admit eight and the ceiling five.
        limited.newCardsPerSession = 5
        let none = try Deck(learningOptions: limited, cards: (0..<20).map { fresh("n\($0)") })
        #expect(evaluate([none]).newCardAllowances == [5])
    }

    @Test func theAllowanceAheadIsSharedByTheCeilingsOfTheDecks() throws {
        var small = options()
        small.newCardsPerSession = 10
        let first = try Deck(learningOptions: small, cards: dueNextWeek(163) + (0..<30).map { fresh("a\($0)") })
        let second = try Deck(learningOptions: options(), cards: (0..<30).map { fresh("b\($0)") })
        let progress = evaluate([first, second])
        let total = progress.newCardAllowances.reduce(0, +)
        #expect(progress.newCardLimit == .nextWeek)
        // The reviews due are those of both decks, and the split is by ceilings, 10 and 30.
        #expect(total < 8)
        #expect(progress.newCardAllowances == DailyGoal.split(total, overCeilings: [10, 30]))
    }

    @Test func pastDaysKeepTheTimeAloneAndOnlyTodaysAllowanceMoves() throws {
        var deck = try Deck(learningOptions: options(), cards: (0..<400).map { fresh("n\($0)") })
        for offset in 0..<9 where offset != 6 { study(&deck, onDay: today - 9 + offset) }
        let date = at(day: today, hour: 12)
        let quiet = evaluate([deck], at: date)
        // A week full of reviews makes today's bound bite.
        deck.cards += dueNextWeek(400)
        let busy = evaluate([deck], at: date)
        #expect(busy.newCardLimit == .nextWeek)
        #expect(busy.newCardAllowances[0] < quiet.newCardAllowances[0])
        #expect(busy.records.count == quiet.records.count && busy.records.count > 8)
        #expect(busy.records.dropLast() == quiet.records.dropLast())
        #expect(busy.ringDays.dropLast() == quiet.ringDays.dropLast())
        #expect(busy.time == quiet.time && busy.pace == quiet.pace)
    }

    @Test func theAllowanceStaysTheSameThroughTheDayAsItsCardsAreStudied() throws {
        var deck = try Deck(learningOptions: options(), cards: dueNextWeek(163) + (0..<30).map { fresh("n\($0)") })
        let before = evaluate([deck], at: at(day: today, hour: 6))
        #expect(before.newCardLimit == .nextWeek && before.newCardAllowances[0] > 1)
        study(&deck, onDay: today, until: { done, _ in done >= 2 })
        let during = evaluate([deck], at: at(day: today, hour: 12))
        #expect(during.ring.done >= 2)
        // What the day's own reviews and new cards add to next week is not counted twice.
        #expect(during.newCardAllowances == before.newCardAllowances)
        #expect(during.ring.goal == before.ring.goal)
    }

    @Test func suspendedCardsAreNotDueAhead() throws {
        var cards = dueNextWeek(300) + (0..<20).map { fresh("n\($0)") }
        for index in 0..<300 { cards[index].isSuspended = true }
        let progress = evaluate([try Deck(learningOptions: options(), cards: cards)])
        #expect(progress.newCardAllowances == [8])
        #expect(progress.nextWeekSeconds == 0)
    }

    @Test func aPausedDeckHoldsNothingOfTheWeekAhead() throws {
        var paused = options()
        paused.isPaused = true
        let heavy = try Deck(learningOptions: paused, cards: dueNextWeek(300))
        let learner = try Deck(learningOptions: options(), cards: (0..<20).map { fresh("n\($0)") })
        #expect(evaluate([heavy, learner]).newCardAllowances == [0, 8])
    }
}
