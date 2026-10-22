import Foundation
import Testing

@testable import VocabCore

/// The ring and the streak, from the review logs alone.
struct DailyGoalTests {
    @Test func theGoalIsThePlanAndStaysWhileItIsWorkedOff() {
        #expect(DailyGoal.goal(reviews: 0, owed: 8, plan: 8) == 8)
        #expect(DailyGoal.goal(reviews: 0, owed: 60, plan: 60) == 60)
        // A plan worked off keeps the goal: each review takes a card out of the plan.
        #expect(DailyGoal.goal(reviews: 3, owed: 5, plan: 8) == DailyGoal.goal(reviews: 4, owed: 4, plan: 8))
        // A card that stays in the plan after its review, an Again, raises it.
        #expect(DailyGoal.goal(reviews: 4, owed: 5, plan: 8) == 9)
        // The plan done: the goal is the plan, whatever is reviewed beyond it.
        #expect(DailyGoal.goal(reviews: 8, owed: 0, plan: 8) == 8)
        #expect(DailyGoal.goal(reviews: 45, owed: 0, plan: 8) == 8)
    }

    @Test func anEmptyPlanIsAGoalOfNothing() {
        #expect(DailyGoal.goal(reviews: 0, owed: 0, plan: 0) == 0)
        #expect(DailyGoal.goal(reviews: 12, owed: 0, plan: 0) == 0)
        // Cards that turned up during the day, new ones that were added, are a plan of their own.
        #expect(DailyGoal.goal(reviews: 0, owed: 3, plan: 0) == 3)
    }

    @Test func aPlanThatIsDoneWithFewerReviewsThanPlannedIsMetAtThoseReviews() {
        // Cards of the plan that were deleted or suspended during the day.
        #expect(DailyGoal.goal(reviews: 3, owed: 0, plan: 8) == 3)
    }

    @Test func aBacklogAsksOnePartOfAWeekRoundedUp() {
        #expect(DailyGoal.backlogSpreadDays == 7)
        #expect(DailyGoal.backlogShare(of: 0, onTime: 0) == 0)
        #expect(DailyGoal.backlogShare(of: 1, onTime: 0) == 1)
        #expect(DailyGoal.backlogShare(of: 7, onTime: 0) == 1)
        #expect(DailyGoal.backlogShare(of: 8, onTime: 0) == 2)
        #expect(DailyGoal.backlogShare(of: 1500, onTime: 0) == 215)
        #expect(DailyGoal.backlogShare(of: 600, onTime: 0) == 86)
        #expect(DailyGoal.backlogShare(of: -3, onTime: 0) == 0)
    }

    @Test func aBacklogClearsAtLeastAsMuchAsANormalDayAsksButNeverMoreThanThereIs() {
        // One missed day's backlog is done in a day: a normal day's worth, all of it if it is smaller.
        #expect(DailyGoal.backlogShare(of: 5, onTime: 30) == 5)
        #expect(DailyGoal.backlogShare(of: 40, onTime: 40) == 40)
        #expect(DailyGoal.backlogShare(of: 41, onTime: 40) == 40)
        // A large backlog still goes by its seventh while the day's own cards are fewer.
        #expect(DailyGoal.backlogShare(of: 1500, onTime: 50) == 215)
        #expect(DailyGoal.backlogShare(of: 1500, onTime: 215) == 215)
        // Many on-time cards and a mid-sized backlog: a normal day's worth.
        #expect(DailyGoal.backlogShare(of: 600, onTime: 120) == 120)
        #expect(DailyGoal.backlogShare(of: 0, onTime: 50) == 0)
        #expect(DailyGoal.backlogShare(of: -3, onTime: -3) == 0)
    }

    @Test func theRingFillsInLaps() {
        var ring = DailyRing(reviews: 5, goal: 20)
        #expect(ring.fraction == 0.25)
        #expect(!ring.isGoalMet)
        #expect(ring.laps == 0)
        ring.reviews = 20
        #expect(ring.isGoalMet)
        #expect(ring.laps == 1)
        ring.reviews = 45
        #expect(ring.fraction == 2.25)
        #expect(ring.laps == 2)
    }

    @Test func aRingWithoutAGoalIsMetAndCountsEachReviewAsALap() {
        #expect(DailyRing(reviews: 0, goal: 0).isGoalMet)
        #expect(DailyRing(reviews: 0, goal: 0).fraction == 0)
        #expect(DailyRing(reviews: 0, goal: 0).laps == 0)
        let ring = DailyRing(reviews: 3, goal: 0)
        #expect(ring.isGoalMet)
        #expect(ring.laps == 3)
        #expect(DailyRing(reviews: -2, goal: -1) == DailyRing(reviews: 0, goal: 0))
    }
}

struct StreakTests {
    func streak(_ reviews: [Int: Int], today: Int, owed: [Int: Int] = [:]) -> Streak {
        Streak.evaluate(reviews: reviews, today: today, owed: { owed[$0] ?? 0 })
    }

    @Test func daysInARowCountAndTodayCountsOnceItsPlanIsDone() {
        let days = Dictionary(uniqueKeysWithValues: (100...104).map { ($0, 12) })
        #expect(streak(days, today: 105, owed: [105: 10]) == Streak(days: 5, repairCards: nil))
        // Ten cards of today's plan left: the day is not met yet, the streak is not broken.
        var withToday = days
        withToday[105] = 5
        #expect(streak(withToday, today: 105, owed: [105: 10]) == Streak(days: 5, repairCards: nil))
        // The plan of today is done.
        #expect(streak(withToday, today: 105) == Streak(days: 6, repairCards: nil))
    }

    @Test func theStreakStartsWithTheFirstReview() {
        #expect(streak([:], today: 100) == Streak(days: 0, repairCards: nil))
        #expect(streak([:], today: 100, owed: [100: 4]) == Streak(days: 0, repairCards: nil))
        // The first day counts once its plan is done; days before it are nobody's.
        #expect(streak([100: 3], today: 100) == Streak(days: 1, repairCards: nil))
        #expect(streak([100: 3], today: 100, owed: [100: 2]) == Streak(days: 0, repairCards: nil))
    }

    @Test func aDayWithAnEmptyPlanCounts() {
        // Reviews on 100 only, then two days on which nothing was due, and today.
        #expect(streak([100: 5], today: 103) == Streak(days: 4, repairCards: nil))
        // Nothing was due today yet, nothing was reviewed: the day is met.
        #expect(streak([100: 5], today: 101) == Streak(days: 2, repairCards: nil))
    }

    @Test func aDayIsJudgedByWhatItOwedAtItsEnd() {
        // 101 owed three cards at its end, whatever was reviewed on it.
        #expect(streak([100: 20, 101: 20, 102: 20], today: 103, owed: [101: 3]) == Streak(days: 4, repairCards: nil))
        #expect(streak([100: 20, 101: 20, 102: 20], today: 103, owed: [101: 3, 102: 1]) == Streak(days: 1, repairCards: nil))
        // Reviews don't make a day: nothing reviewed on 101, but nothing owed either.
        #expect(streak([100: 20, 102: 20], today: 103) == Streak(days: 4, repairCards: nil))
    }

    @Test func theOwedPlanIsAskedForEveryDayFromTheFirstReviewToToday() {
        var asked: [Int] = []
        _ = Streak.evaluate(reviews: [100: 5, 103: 5, 90: 0], today: 105) { day in
            asked.append(day)
            return 0
        }
        #expect(asked == [100, 101, 102, 103, 104, 105])
    }

    @Test func aMissedDayIsRepairedByCompletingThePlanOfTheNextDay() {
        let days = Dictionary(uniqueKeysWithValues: (100...102).map { ($0, 20) })
        // 103 is missed: its plan was not done. 104 completes its own plan, which holds what 103 left.
        #expect(streak(days, today: 105, owed: [103: 6, 105: 4]) == Streak(days: 5, repairCards: nil))
        #expect(streak(days, today: 105, owed: [103: 6]) == Streak(days: 6, repairCards: nil))
        #expect(streak(days, today: 106, owed: [103: 6]) == Streak(days: 7, repairCards: nil))
    }

    @Test func todayStillCanRepairYesterday() {
        let days = Dictionary(uniqueKeysWithValues: (100...102).map { ($0, 20) })
        // 103 is missed, today is 104: the streak stands as it was, with the cards of the plan that repair it.
        #expect(streak(days, today: 104, owed: [103: 6, 104: 9]) == Streak(days: 3, repairCards: 9))
        // Fewer cards left of the plan, fewer to do.
        #expect(streak(days, today: 104, owed: [103: 6, 104: 2]) == Streak(days: 3, repairCards: 2))
        // The plan done: repaired, both days count.
        #expect(streak(days, today: 104, owed: [103: 6]) == Streak(days: 5, repairCards: nil))
    }

    @Test func twoMissedDaysInARowBreakTheStreakWhateverComesAfter() {
        let days = Dictionary(uniqueKeysWithValues: (100...102).map { ($0, 20) })
        let missed = [103: 6, 104: 8]
        // 105 completes its plan, which doesn't bring the two days back.
        #expect(streak(days, today: 105, owed: missed) == Streak(days: 1, repairCards: nil))
        #expect(streak(days, today: 106, owed: missed) == Streak(days: 2, repairCards: nil))
        // Today not done either: the streak is over, not waiting for a repair.
        #expect(streak(days, today: 105, owed: missed.merging([105: 3]) { $1 }) == Streak(days: 0, repairCards: nil))
    }

    @Test func aRepairedStreakCanBeRepairedAgain() {
        let days: [Int: Int] = [100: 20, 102: 20, 104: 20]
        // 100 counts one, 101 is made up by 102 (3), 103 by 104 (5).
        #expect(streak(days, today: 104, owed: [101: 5, 103: 5]) == Streak(days: 5, repairCards: nil))
        #expect(streak(days, today: 102, owed: [101: 5]) == Streak(days: 3, repairCards: nil))
    }

    @Test func aMissedDayBeforeAnyStreakHasNothingToRepair() {
        // The first day is missed, the second made up for nothing: the streak starts with the second.
        #expect(streak([101: 3], today: 103, owed: [101: 5]) == Streak(days: 2, repairCards: nil))
        #expect(streak([101: 3], today: 102, owed: [101: 5, 102: 4]) == Streak(days: 0, repairCards: nil))
    }
}

/// The decks' side: reviews by study day, the owed plan, and everything together.
struct DailyProgressTests {
    let calendar = StudyCalendar.testing
    /// 2026-10-05 18:00 in Berlin.
    let now = Date(timeIntervalSince1970: 1_791_216_000)
    var today: Int { calendar.dayNumber(for: now) }

    func options() -> LearningOptions {
        var options = LearningOptions()
        options.fuzzing = false
        options.cardsPerSession = nil
        options.newCardsPerSession = nil
        options.newProductionPerSession = nil
        return options
    }

    /// A card learned with two Goods on study day `day`, as the scheduler replays its log, so the
    /// card is what its log says.
    func learned(_ question: String, onDay day: Int) -> Card {
        let first = calendar.start(ofDay: day).addingTimeInterval(10 * 3600)
        let log = [ReviewLogEntry(date: first, grade: .good, mode: .revealed), ReviewLogEntry(date: first.addingTimeInterval(60), grade: .good, mode: .revealed)]
        return Scheduler(learningOptions: options(), calendar: calendar).replaying(log, of: Card(question: question, answer: question))
    }

    /// Days from learning a card to its first review, without fuzz the same for every card.
    var interval: Int {
        calendar.dayNumber(for: learned("probe", onDay: today).learningState!.due) - today
    }

    /// A review card due on study day `day`: on time on that day, backlog on later ones.
    func due(_ question: String, onDay day: Int) -> Card {
        learned(question, onDay: day - interval)
    }

    /// Reviews every card the session of `date` takes, all with Good.
    func reviewPlan(of deck: inout Deck, at date: Date) {
        var study = StudySession(deck: deck, at: date, calendar: calendar, random: SeededRandom(seed: 1), reviewMode: .revealed)
        while let id = study.session.currentCardID {
            let card = study.review(.good, of: deck.card(withID: id)!, with: deck.learningOptions, at: date, calendar: calendar)!
            deck.cards[deck.index(of: id)!] = card
        }
    }

    /// Reviews the first `count` cards of the plan of `date`, all with Good; with `all`, every card that is due,
    /// the rest of the backlog too, as the stream does once the plan is done.
    func review(_ count: Int, of deck: inout Deck, at date: Date, all: Bool = false) {
        var study =
            all
            ? StudySession(catchingUpIn: deck, at: date, calendar: calendar, random: SeededRandom(seed: 1), reviewMode: .revealed)
            : StudySession(deck: deck, at: date, calendar: calendar, random: SeededRandom(seed: 1), reviewMode: .revealed)
        for _ in 0..<count {
            let id = study.session.currentCardID!
            let card = study.review(.good, of: deck.card(withID: id)!, with: deck.learningOptions, at: date, calendar: calendar)!
            deck.cards[deck.index(of: id)!] = card
        }
    }

    func evaluate(_ decks: [Deck], at date: Date? = nil) -> DailyProgress {
        DailyProgress.evaluate(decks.map { DeckActivity(deck: $0, calendar: calendar) }, at: date ?? now, calendar: calendar)
    }

    @Test func reviewsAreCountedByStudyDayWithTheRolloverAtFourInTheMorning() throws {
        let day = today
        let start = calendar.start(ofDay: day + 1)
        let dates = [
            start.addingTimeInterval(-6 * 3600),  // 22:00
            start.addingTimeInterval(-2.5 * 3600),  // 01:30 of the next date, still study day `day`
            start.addingTimeInterval(-1),  // 03:59:59
            start,  // 04:00:00
            start.addingTimeInterval(3600),
        ]
        var card = Card(question: "q", answer: "a")
        card.log = dates.map { ReviewLogEntry(date: $0, grade: .good) }
        let deck = try Deck(learningOptions: options(), cards: [card, Card(question: "p", answer: "b")])
        #expect(DeckActivity(deck: deck, calendar: calendar).reviewsByDay == [day: 3, day + 1: 2])
    }

    @Test func reviewsAreCountedLikeTheCalendarDoesAroundTheEndOfDaylightSavingTime() throws {
        // Berlin turns the clocks back on 2026-10-25 at 03:00 to 02:00.
        let start = Date(timeIntervalSince1970: 1_792_880_000)  // 2026-10-25 00:13 CEST
        var card = Card(question: "q", answer: "a")
        card.log = stride(from: 0.0, to: 3 * 86400, by: 7 * 60).map { ReviewLogEntry(date: start.addingTimeInterval($0), grade: .good) }
        let deck = try Deck(learningOptions: options(), cards: [card])
        var expected: [Int: Int] = [:]
        for entry in card.log {
            expected[calendar.dayNumber(for: entry.date), default: 0] += 1
        }
        #expect(DeckActivity(deck: deck, calendar: calendar).reviewsByDay == expected)
        #expect(expected.count >= 3)
    }

    @Test func theGoalIsThePlanAndTheRingFillsAsItIsWorkedOff() throws {
        var deck = try Deck(learningOptions: options(), cards: (0..<8).map { due("c\($0)", onDay: today) })
        var progress = evaluate([deck])
        #expect(progress.ring == DailyRing(reviews: 0, goal: 8))
        reviewPlan(of: &deck, at: now)
        progress = evaluate([deck])
        #expect(progress.ring == DailyRing(reviews: 8, goal: 8))
        #expect(progress.ring.isGoalMet)
        #expect(progress.streak.repairCards == nil)
    }

    @Test func aBigPlanIsTheGoalAsItIsAndLapsComeAfterIt() throws {
        var deck = try Deck(learningOptions: options(), cards: (0..<50).map { due("c\($0)", onDay: today) })
        #expect(evaluate([deck]).ring == DailyRing(reviews: 0, goal: 50))
        reviewPlan(of: &deck, at: now)
        #expect(evaluate([deck]).ring == DailyRing(reviews: 50, goal: 50))
    }

    @Test func newCardsWithinTheLimitsAreInTheGoal() throws {
        var options = options()
        options.newCardsPerSession = 5
        var deck = try Deck(learningOptions: options, cards: (0..<4).map { due("c\($0)", onDay: today) } + (0..<30).map { Card(question: "n\($0)", answer: "x") })
        // Four reviews and five new cards: a new card asks two Goods to leave the plan, so the plan
        // is 4 + 5 * 2 answers, and the ring is full when they are given.
        let answers = 4 + 5 * options.steps
        #expect(StudySession.counts(for: deck, at: now, calendar: calendar).total == 9)
        #expect(evaluate([deck]).ring == DailyRing(reviews: 0, goal: answers))
        reviewPlan(of: &deck, at: now)
        #expect(evaluate([deck]).ring == DailyRing(reviews: answers, goal: answers))
        #expect(evaluate([deck]).ring.isGoalMet)
    }

    @Test func answersBeyondThePlanCountTowardTheLaps() throws {
        // A plan of 6, then reviews ahead: cards not due until tomorrow.
        var deck = try Deck(learningOptions: options(), cards: (0..<6).map { due("c\($0)", onDay: today) } + (0..<14).map { due("a\($0)", onDay: today + 1) })
        reviewPlan(of: &deck, at: now)
        var ahead = StudySession(reviewingAheadIn: deck, at: now, calendar: calendar, random: SeededRandom(seed: 1), reviewMode: .revealed)
        for _ in 0..<14 {
            let id = ahead.session.currentCardID!
            deck.cards[deck.index(of: id)!] = ahead.review(.good, of: deck.card(withID: id)!, with: deck.learningOptions, at: now, calendar: calendar)!
        }
        let ring = evaluate([deck]).ring
        #expect(ring == DailyRing(reviews: 20, goal: 6))
        #expect(ring.laps == 3)
        #expect(ring.isGoalMet)
    }

    @Test func aPlanOfNothingIsAGoalOfNothingAndTheDayCounts() throws {
        // Learned `interval - 1` days ago, nothing due before tomorrow.
        let deck = try Deck(learningOptions: options(), cards: (0..<5).map { due("c\($0)", onDay: today + 1) })
        let progress = evaluate([deck])
        #expect(progress.ring == DailyRing(reviews: 0, goal: 0))
        #expect(progress.ring.isGoalMet)
        // The days since the learning asked nothing, and each counts, today's too.
        #expect(progress.streak == Streak(days: interval, repairCards: nil))
    }

    @Test func aMissedDayIsRepairedByCompletingTheNextPlan() throws {
        // Eight cards were due yesterday and nobody studied: the day is missed.
        var deck = try Deck(learningOptions: options(), cards: (0..<8).map { due("c\($0)", onDay: today - 1) })
        let before = interval
        // The days from the learning to the day before yesterday asked nothing: they count. Yesterday
        // is missed, today is open with the plan, whose share of the eight cards left over is two.
        var progress = evaluate([deck])
        #expect(progress.ring == DailyRing(reviews: 0, goal: 2))
        #expect(progress.streak == Streak(days: before, repairCards: 2))
        review(1, of: &deck, at: now)
        progress = evaluate([deck])
        #expect(progress.streak == Streak(days: before, repairCards: 1))
        // The plan of today done: yesterday counts, too.
        review(1, of: &deck, at: now)
        progress = evaluate([deck])
        #expect(progress.ring == DailyRing(reviews: 2, goal: 2))
        #expect(progress.streak == Streak(days: before + 2, repairCards: nil))
    }

    @Test func twoMissedDaysInARowBreakTheStreak() throws {
        // Eight cards were due the day before yesterday; yesterday and the day before were missed.
        var deck = try Deck(learningOptions: options(), cards: (0..<8).map { due("c\($0)", onDay: today - 2) })
        #expect(evaluate([deck]).streak == Streak(days: 0, repairCards: nil))
        reviewPlan(of: &deck, at: now)
        // Today's plan is done, and the two days before it still are missed: today is a streak of one.
        #expect(evaluate([deck]).streak == Streak(days: 1, repairCards: nil))
    }

    @Test func aPastDayIsJudgedByWhatItOwedAtItsEnd() throws {
        // Eight cards fell due the day before yesterday: that day and the one after it owe them while any waits.
        var deck = try Deck(learningOptions: options(), cards: (0..<8).map { due("c\($0)", onDay: today - 2) })
        let activity: () -> DeckActivity = { DeckActivity(deck: deck, calendar: calendar) }
        review(7, of: &deck, at: now, all: true)
        #expect(activity().owed(onDayOf: today - 2, now: now, calendar: calendar).total == 1)
        #expect(activity().owed(onDayOf: today - 1, now: now, calendar: calendar).total == 1)
        // Two missed days in a row, and the plan of today, which is a share of one card, is done.
        #expect(evaluate([deck]).streak == Streak(days: 1, repairCards: nil))
        // The last one done, a day late: both days owe nothing now, so they count.
        review(1, of: &deck, at: now, all: true)
        #expect(activity().owed(onDayOf: today - 2, now: now, calendar: calendar).total == 0)
        #expect(activity().owed(onDayOf: today - 1, now: now, calendar: calendar).total == 0)
        #expect(evaluate([deck]).streak == Streak(days: interval + 3, repairCards: nil))
    }

    @Test func aCardThatDidNotExistYetWasNotInThePlanOfThatDay() throws {
        var options = options()
        options.newCardsPerSession = 5
        // Studied for a while, then ten new cards were added today.
        var cards = (0..<3).map { due("c\($0)", onDay: today + 1) }
        cards += (0..<10).map { Card(id: UUID(), question: "n\($0)", answer: "x", created: now.addingTimeInterval(-3600)) }
        let deck = try Deck(learningOptions: options, cards: cards)
        let activity = DeckActivity(deck: deck, calendar: calendar)
        #expect(activity.owed(onDayOf: today - 1, now: now, calendar: calendar).total == 0)
        #expect(activity.owed(onDayOf: today, now: now, calendar: calendar).total == 5)
    }

    @Test func aBacklogOfFifteenHundredAsksTheOnTimeCardsAndTwoHundredFifteen() throws {
        let onTime = (0..<12).map { due("t\($0)", onDay: today) }
        let backlog = (0..<1500).map { due("b\($0)", onDay: today - 1 - $0 % 5) }
        var deck = try Deck(learningOptions: options(), cards: onTime + backlog)
        let progress = evaluate([deck])
        #expect(progress.ring == DailyRing(reviews: 0, goal: 12 + 215))
        let counts = StudySession.counts(for: deck, at: now, calendar: calendar)
        #expect(counts.total == 12 + 215)
        #expect(counts.catchUp == 1500 - 215)
        // The most forgotten of the backlog come first, and all the on-time cards, which are less forgotten, come too.
        reviewPlan(of: &deck, at: now)
        #expect(evaluate([deck]).ring == DailyRing(reviews: 12 + 215, goal: 12 + 215))
        #expect(StudySession.counts(for: deck, at: now, calendar: calendar).total == 0)
        #expect(StudySession.counts(for: deck, at: now, calendar: calendar).catchUp == 1500 - 215)
    }

    @Test func aSmallBacklogIsDoneInADayAsLongAsTheDaysOwnCardsAreMore() throws {
        // One missed day: five cards left over, thirty due today.
        var deck = try Deck(learningOptions: options(), cards: (0..<30).map { due("t\($0)", onDay: today) } + (0..<5).map { due("b\($0)", onDay: today - 1) })
        var counts = StudySession.counts(for: deck, at: now, calendar: calendar)
        #expect(counts.total == 35)
        #expect(counts.catchUp == 0)
        #expect(evaluate([deck]).ring == DailyRing(reviews: 0, goal: 35))
        // Nothing of the plan is left over once it is done.
        reviewPlan(of: &deck, at: now)
        counts = StudySession.counts(for: deck, at: now, calendar: calendar)
        #expect(counts.total == 0)
        #expect(counts.catchUp == 0)
        #expect(evaluate([deck]).ring == DailyRing(reviews: 35, goal: 35))
    }

    @Test func theBacklogShareGoesBySeventhsWhileTheDaysOwnCardsAreFewer() throws {
        // 1500 overdue and 50 due today: the share is 215, not the 50 of a normal day.
        let deck = try Deck(
            learningOptions: options(), cards: (0..<50).map { due("t\($0)", onDay: today) } + (0..<1500).map { due("b\($0)", onDay: today - 1 - $0 % 5) })
        #expect(StudySession.counts(for: deck, at: now, calendar: calendar).total == 50 + 215)
        #expect(evaluate([deck]).ring == DailyRing(reviews: 0, goal: 50 + 215))
    }

    @Test func aBacklogAsBigAsTheDaysOwnCardsIsDoneInADayAndTheShareStaysAsItIsWorkedOff() throws {
        // Forty overdue, forty due today: eighty, not forty-six.
        var deck = try Deck(learningOptions: options(), cards: (0..<40).map { due("t\($0)", onDay: today) } + (0..<40).map { due("b\($0)", onDay: today - 1) })
        #expect(StudySession.counts(for: deck, at: now, calendar: calendar).total == 80)
        #expect(StudySession.counts(for: deck, at: now, calendar: calendar).catchUp == 0)
        // Worked off in steps, the goal is the same at every one, and the plan shrinks by what is reviewed.
        var done = 0
        for step in [10, 30, 5, 35] {
            review(step, of: &deck, at: now)
            done += step
            #expect(evaluate([deck]).ring == DailyRing(reviews: done, goal: 80), "after \(done)")
            #expect(StudySession.counts(for: deck, at: now, calendar: calendar).total == 80 - done, "after \(done)")
        }
        #expect(evaluate([deck]).ring.isGoalMet)
    }

    @Test func sixHundredOverdueAndNothingDueAsksEightySix() throws {
        let deck = try Deck(learningOptions: options(), cards: (0..<600).map { due("b\($0)", onDay: today - 1 - $0 % 3) })
        #expect(StudySession.counts(for: deck, at: now, calendar: calendar).total == 86)
        #expect(evaluate([deck]).ring == DailyRing(reviews: 0, goal: 86))
    }

    @Test func theSizeOfASessionCapsNeitherTheGoalNorWhatIsShown() throws {
        // The default size of a session, 100, is the size of a segment of the stream, no cap on the plan.
        var options = options()
        options.cardsPerSession = LearningOptions().cardsPerSession
        #expect(options.cardsPerSession == 100)
        let onTime = (0..<12).map { due("t\($0)", onDay: today) }
        let backlog = (0..<1500).map { due("b\($0)", onDay: today - 1 - $0 % 5) }
        var deck = try Deck(learningOptions: options, cards: onTime + backlog)
        let goal = 12 + 215
        #expect(StudySession.counts(for: deck, at: now, calendar: calendar).total == goal)
        #expect(evaluate([deck]).ring == DailyRing(reviews: 0, goal: goal))
        // The stream takes the plan in segments of a hundred, and the goal doesn't grow with them.
        #expect(StudySession(deck: deck, at: now, calendar: calendar, random: SeededRandom(seed: 1)).session.totalCount == 100)
        var done = 0
        while StudySession.counts(for: deck, at: now, calendar: calendar).total > 0 {
            let segment = StudySession(deck: deck, at: now, calendar: calendar, random: SeededRandom(seed: 1)).session.totalCount
            review(segment, of: &deck, at: now)
            done += segment
            let ring = evaluate([deck]).ring
            #expect(ring == DailyRing(reviews: done, goal: goal))
            #expect(StudySession.counts(for: deck, at: now, calendar: calendar).total == goal - done)
        }
        #expect(done == goal)
        #expect(evaluate([deck]).ring.isGoalMet)
    }

    @Test func withoutABacklogTheGoalIsThePlan() throws {
        let deck = try Deck(learningOptions: options(), cards: (0..<30).map { due("c\($0)", onDay: today) })
        let counts = StudySession.counts(for: deck, at: now, calendar: calendar)
        #expect(counts.catchUp == 0)
        #expect(evaluate([deck]).ring.goal == counts.total)
        #expect(counts.total == 30)
    }

    @Test func theBacklogShrinksDayByDayAsItIsWorkedOff() throws {
        var deck = try Deck(learningOptions: options(), cards: (0..<140).map { due("b\($0)", onDay: today - 1) })
        var remaining = 140
        let first = today - 1 - interval
        for day in 0..<4 {
            let date = now.addingTimeInterval(Double(day) * 86400)
            let share = DailyGoal.backlogShare(of: remaining, onTime: 0)
            #expect(evaluate([deck], at: date).ring == DailyRing(reviews: 0, goal: share), "day \(day)")
            reviewPlan(of: &deck, at: date)
            #expect(evaluate([deck], at: date).ring == DailyRing(reviews: share, goal: share), "day \(day) done")
            // Every day's plan was done, so the streak runs from the learning on: the day the cards were
            // due was missed, which the plan of the day after it repaired.
            #expect(evaluate([deck], at: date).streak == Streak(days: today + day - first + 1, repairCards: nil), "day \(day) streak")
            remaining -= share
        }
        #expect(remaining == 74)
    }

    @Test func theStreakIsJudgedAgainstTheGoal() throws {
        // Seventy cards, all due three days ago, with nothing done since: a plan of ten a day.
        var deck = try Deck(learningOptions: options(), cards: (0..<70).map { due("b\($0)", onDay: today - 3) })
        #expect(evaluate([deck]).ring == DailyRing(reviews: 0, goal: 10))
        // Nine of the ten: one card short of the goal, the day is not met.
        review(9, of: &deck, at: now)
        var progress = evaluate([deck])
        #expect(progress.ring == DailyRing(reviews: 9, goal: 10))
        #expect(!progress.ring.isGoalMet)
        #expect(progress.streak.days == 0)
        // The tenth meets the goal and the day. The days since the cards were due are missed.
        review(1, of: &deck, at: now)
        progress = evaluate([deck])
        #expect(progress.ring == DailyRing(reviews: 10, goal: 10))
        #expect(progress.ring.isGoalMet)
        #expect(progress.streak == Streak(days: 1, repairCards: nil))
        // Catching up beyond the goal fills the laps and changes neither the goal nor the streak.
        review(20, of: &deck, at: now, all: true)
        progress = evaluate([deck])
        #expect(progress.ring == DailyRing(reviews: 30, goal: 10))
        #expect(progress.ring.laps == 3)
        #expect(progress.streak == Streak(days: 1, repairCards: nil))
    }

    @Test func decksAddUp() throws {
        var first = try Deck(learningOptions: options(), cards: (0..<30).map { due("a\($0)", onDay: today) })
        let second = try Deck(learningOptions: options(), cards: (0..<5).map { due("b\($0)", onDay: today) })
        // Together the plan is 35 cards, whichever deck the reviews are in.
        #expect(evaluate([first, second]).ring == DailyRing(reviews: 0, goal: 35))
        reviewPlan(of: &first, at: now)
        var progress = evaluate([first, second])
        #expect(progress.ring == DailyRing(reviews: 30, goal: 35))
        #expect(!progress.ring.isGoalMet)
        // One deck alone is a smaller picture.
        #expect(evaluate([second]).ring == DailyRing(reviews: 0, goal: 5))
        var rest = second
        reviewPlan(of: &rest, at: now)
        progress = evaluate([first, rest])
        #expect(progress.ring == DailyRing(reviews: 35, goal: 35))
    }

    @Test func aReviewAtThreeFiftyNineBelongsToTheStudyDayBefore() throws {
        // 2026-10-06 03:59:59 and 04:00:00 in Berlin.
        let before = calendar.start(ofDay: today + 1).addingTimeInterval(-1)
        let after = calendar.start(ofDay: today + 1)
        var card = Card(question: "q", answer: "a")
        card.log = (0..<25).map { _ in ReviewLogEntry(date: before, grade: .good) } + [ReviewLogEntry(date: after, grade: .good)]
        card.learningState = LearningState(phase: .review, stability: 30, difficulty: 5, lastReview: after, due: after.addingTimeInterval(30 * 86400), reviews: 26)
        let deck = try Deck(learningOptions: options(), cards: [card])
        // Just before four the day is still 2026-10-05: 25 reviews of a card that was new that day, so
        // its plan was the card's two steps.
        let evening = evaluate([deck], at: before)
        #expect(evening.ring == DailyRing(reviews: 25, goal: 2))
        #expect(evening.ring.laps == 12)
        // A second later it is the next day: one review of it, and nothing was due then, so
        // yesterday and today are both in the streak.
        let morning = evaluate([deck], at: after)
        #expect(morning.ring == DailyRing(reviews: 1, goal: 0))
        #expect(morning.streak.days == 2)
    }

    @Test func theNewCardLoadOfOneCardIsOneOrTwoReviewsInTheNextWeek() {
        let reviews = NewCardLoad.reviewsOfOneCard(options: LearningOptions(), at: now, calendar: calendar)
        #expect((1...2).contains(reviews))
    }
}

struct NewCardLoadTests {
    let calendar = StudyCalendar.testing
    let now = Date(timeIntervalSince1970: 1_791_216_000)

    @Test func theLoadGrowsWithTheNumberOfCardsAndIsZeroForNone() {
        let options = LearningOptions()
        #expect(NewCardLoad.reviewsPerDay(addingNewCards: 0, options: options, at: now, calendar: calendar) == 0)
        let ten = NewCardLoad.reviewsPerDay(addingNewCards: 10, options: options, at: now, calendar: calendar)
        let twenty = NewCardLoad.reviewsPerDay(addingNewCards: 20, options: options, at: now, calendar: calendar)
        #expect(ten > 0)
        #expect(twenty == 2 * ten)
        // With the default parameters a Good on a new card comes back in about three days, and
        // the next review is far beyond the week: ten cards add about a review a day.
        #expect((1.0...3.0).contains(ten))
    }

    @Test func aHigherTargetRecallMeansMoreReviews() {
        var low = LearningOptions()
        low.targetRecall = 0.7
        var high = LearningOptions()
        high.targetRecall = 0.97
        let lowLoad = NewCardLoad.reviewsPerDay(addingNewCards: 10, options: low, at: now, calendar: calendar)
        let highLoad = NewCardLoad.reviewsPerDay(addingNewCards: 10, options: high, at: now, calendar: calendar)
        #expect(highLoad > lowLoad)
    }
}

struct MistakesTodayTests {
    let calendar = StudyCalendar.testing
    let now = Date(timeIntervalSince1970: 1_791_216_000)

    func card(_ question: String, _ log: [(TimeInterval, Grade)], suspended: Bool = false) -> Card {
        var card = Card(question: question, answer: question, log: log.map { ReviewLogEntry(date: now.addingTimeInterval($0.0), grade: $0.1) })
        card.isSuspended = suspended
        return card
    }

    @Test func mistakesOfTheStudyDayAreCardsWithAnAgainOnIt() throws {
        let day: TimeInterval = 86400
        let again = card("again today", [(-3600, .again)])
        let mixed = card("good then again", [(-day, .good), (-7200, .good), (-60, .again)])
        let fixed = card("again yesterday", [(-day, .again), (-60, .good)])
        let suspended = card("suspended", [(-60, .again)], suspended: true)
        let deck = try Deck(learningOptions: LearningOptions(), cards: [fixed, again, suspended, mixed])
        #expect(deck.mistakes(onDayOf: now, calendar: calendar) == [again.id, mixed.id])
    }

    @Test func theStudyDayEndsAtFourInTheMorning() throws {
        let beforeFour = calendar.start(ofDay: calendar.dayNumber(for: now) + 1).addingTimeInterval(-1)
        let atFour = calendar.start(ofDay: calendar.dayNumber(for: now) + 1)
        let evening = Card(question: "q", answer: "a", log: [ReviewLogEntry(date: now, grade: .again)])
        let deck = try Deck(learningOptions: LearningOptions(), cards: [evening])
        #expect(deck.mistakes(onDayOf: beforeFour, calendar: calendar) == [evening.id])
        #expect(deck.mistakes(onDayOf: atFour, calendar: calendar).isEmpty)
    }
}
