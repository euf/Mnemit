import Foundation
import Testing

@testable import VocabCore

/// The ring and the streak, from the review logs alone.
struct DailyGoalTests {
    @Test func theGoalIsTheWholePlanBetweenOneAndTwenty() {
        #expect(DailyGoal.goal(reviews: 0, owed: 0) == 1)
        #expect(DailyGoal.goal(reviews: 0, owed: 8) == 8)
        #expect(DailyGoal.goal(reviews: 0, owed: 60) == 20)
        // A plan worked off keeps the goal: each review takes a card out of the plan.
        #expect(DailyGoal.goal(reviews: 3, owed: 5) == DailyGoal.goal(reviews: 4, owed: 4))
        // A card that stays in the plan after its review, an Again, raises it.
        #expect(DailyGoal.goal(reviews: 4, owed: 5) == 9)
        #expect(DailyGoal.goal(reviews: 45, owed: 0) == 20)
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
        #expect(DailyRing(reviews: 3, goal: 0).goal == 1)
    }
}

struct StreakTests {
    /// Every day with this many reviews meets the goal.
    let met = DailyGoal.reviewsPerDay

    func streak(_ reviews: [Int: Int], today: Int, owed: @escaping (Int) -> Int = { _ in 0 }) -> Streak {
        Streak.evaluate(reviews: reviews, today: today, owed: owed)
    }

    @Test func daysInARowCountAndTodayCountsOnceItsGoalIsMet() {
        let days = Dictionary(uniqueKeysWithValues: (100...104).map { ($0, met) })
        #expect(streak(days, today: 105, owed: { _ in 10 }) == Streak(days: 5, repairReviews: nil))
        var withToday = days
        withToday[105] = 5
        // Five reviews with ten cards of the plan left: the goal is not met yet, the streak is not broken.
        #expect(streak(withToday, today: 105, owed: { _ in 10 }) == Streak(days: 5, repairReviews: nil))
        // The plan of today is done: the goal is, too.
        #expect(streak(withToday, today: 105, owed: { _ in 0 }) == Streak(days: 6, repairReviews: nil))
        withToday[105] = met
        #expect(streak(withToday, today: 105, owed: { _ in 10 }) == Streak(days: 6, repairReviews: nil))
    }

    @Test func noReviewsAtAllIsNoStreak() {
        #expect(streak([:], today: 100) == Streak(days: 0, repairReviews: nil))
        #expect(streak([90: met], today: 100) == Streak(days: 0, repairReviews: nil))
    }

    @Test func aSmallPlanThatIsDoneMeetsTheGoalAndOneThatIsNotDoesNot() {
        // Eight reviews, nothing left of the plan.
        #expect(streak([100: 8], today: 101, owed: { _ in 0 }).days == 1)
        // Eight reviews of a plan of twenty.
        #expect(streak([100: 8], today: 101, owed: { _ in 12 }).days == 0)
        // Too many for a goal of eight, but not for one of twenty.
        #expect(streak([100: 19], today: 101, owed: { _ in 1 }).days == 0)
    }

    @Test func theOwedPlanIsAskedOnlyForDaysWithSomeButFewReviews() {
        var asked: [Int] = []
        _ = streak([100: met, 101: 0, 102: 7, 103: met + 5, 104: 1], today: 105) { day in
            asked.append(day)
            return 0
        }
        #expect(Set(asked) == [102, 104])
    }

    @Test func oneMissedDayIsRepairedByFortyReviewsTheNextDay() {
        let before = Dictionary(uniqueKeysWithValues: (100...102).map { ($0, met) })
        // 103 is missed.
        var days = before
        days[104] = DailyGoal.repairReviews
        #expect(streak(days, today: 104) == Streak(days: 5, repairReviews: nil))
        #expect(streak(days, today: 105) == Streak(days: 5, repairReviews: nil))
        days[105] = met
        #expect(streak(days, today: 105) == Streak(days: 6, repairReviews: nil))
    }

    @Test func todayStillCanRepairYesterday() {
        let days = Dictionary(uniqueKeysWithValues: (100...102).map { ($0, met) })
        // 103 is missed, today is 104: the streak stands as it was, with the repair open.
        #expect(streak(days, today: 104) == Streak(days: 3, repairReviews: DailyGoal.repairReviews))
        var withToday = days
        withToday[104] = met + 10
        // The goal is met, but not the repair: the streak stays and waits.
        #expect(streak(withToday, today: 104) == Streak(days: 3, repairReviews: DailyGoal.repairReviews))
        withToday[104] = DailyGoal.repairReviews
        #expect(streak(withToday, today: 104) == Streak(days: 5, repairReviews: nil))
    }

    @Test func aDayAfterTheMissedOneWithTooFewReviewsBreaksTheStreak() {
        var days = Dictionary(uniqueKeysWithValues: (100...102).map { ($0, met) })
        days[104] = DailyGoal.repairReviews - 1
        // The streak starts again with 104.
        #expect(streak(days, today: 105) == Streak(days: 1, repairReviews: nil))
        days[105] = met
        #expect(streak(days, today: 105) == Streak(days: 2, repairReviews: nil))
    }

    @Test func twoMissedDaysBreakTheStreakWhateverComesAfter() {
        var days = Dictionary(uniqueKeysWithValues: (100...102).map { ($0, met) })
        days[105] = 100
        #expect(streak(days, today: 105) == Streak(days: 1, repairReviews: nil))
        #expect(streak(days, today: 106) == Streak(days: 1, repairReviews: nil))
        // Nothing was reviewed since: the streak is over, not waiting for a repair.
        #expect(streak(Dictionary(uniqueKeysWithValues: (100...102).map { ($0, met) }), today: 105) == Streak(days: 0, repairReviews: nil))
    }

    @Test func aRepairedStreakCanBeRepairedAgain() {
        let days: [Int: Int] = [100: met, 102: DailyGoal.repairReviews, 104: DailyGoal.repairReviews]
        // 100 counts one, 101 is made up by 102 (3), 103 by 104 (5).
        #expect(streak(days, today: 104) == Streak(days: 5, repairReviews: nil))
        #expect(streak(days, today: 102) == Streak(days: 3, repairReviews: nil))
    }

    @Test func aMissedDayBeforeAnyStreakHasNothingToRepair() {
        // No day before 101 has a review; 102 is missed, 103 has forty.
        #expect(streak([101: 3, 103: 40], today: 103, owed: { _ in 5 }) == Streak(days: 1, repairReviews: nil))
        // Without a streak the missed day isn't made up, only today counts.
        #expect(streak([103: 40], today: 103) == Streak(days: 1, repairReviews: nil))
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

    /// A review card due `dueDaysAgo` study days before `date`.
    func due(_ question: String, dueDaysAgo: Int = 1, at date: Date) -> Card {
        let last = date.addingTimeInterval(-Double(dueDaysAgo + 3) * 86400)
        let dueDate = calendar.start(ofDay: calendar.dayNumber(for: date) - dueDaysAgo)
        let state = LearningState(phase: .review, stability: 3, difficulty: 5, lastReview: last, due: dueDate, reviews: 1)
        return Card(question: question, answer: question, learningState: state, log: [ReviewLogEntry(date: last, grade: .good)])
    }

    /// Reviews every card the session of `date` takes, all with Good.
    func reviewPlan(of deck: inout Deck, at date: Date) {
        var study = StudySession(deck: deck, at: date, calendar: calendar, random: SeededRandom(seed: 1), reviewMode: .revealed)
        while let id = study.session.currentCardID {
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

    @Test func theRingStartsAtTheGoalOfThePlanAndFillsAsItIsWorkedOff() throws {
        var deck = try Deck(learningOptions: options(), cards: (0..<8).map { due("c\($0)", at: now) })
        var progress = evaluate([deck])
        #expect(progress.ring == DailyRing(reviews: 0, goal: 8))
        #expect(progress.streak == Streak(days: 0, repairReviews: nil))
        reviewPlan(of: &deck, at: now)
        progress = evaluate([deck])
        #expect(progress.ring == DailyRing(reviews: 8, goal: 8))
        #expect(progress.ring.isGoalMet)
        #expect(progress.streak.days == 1)
    }

    @Test func aBigPlanHasTheGoalOfTwentyAndLapsAfterwards() throws {
        var deck = try Deck(learningOptions: options(), cards: (0..<50).map { due("c\($0)", at: now) })
        #expect(evaluate([deck]).ring == DailyRing(reviews: 0, goal: 20))
        reviewPlan(of: &deck, at: now)
        let ring = evaluate([deck]).ring
        #expect(ring.reviews == 50)
        #expect(ring.goal == 20)
        #expect(ring.laps == 2)
    }

    @Test func aSmallPlanFinishedYesterdayKeepsTheStreakAndAnUnfinishedOneDoesNot() throws {
        let yesterday = now.addingTimeInterval(-86400)
        let tomorrow = now.addingTimeInterval(86400)
        var finished = try Deck(learningOptions: options(), cards: (0..<8).map { due("c\($0)", at: yesterday) })
        reviewPlan(of: &finished, at: yesterday)
        #expect(evaluate([finished], at: now).streak.days == 1)
        #expect(evaluate([finished], at: tomorrow).streak == Streak(days: 1, repairReviews: DailyGoal.repairReviews))

        // Eight of thirty reviewed, the rest still overdue: the day was not done.
        var unfinished = try Deck(learningOptions: options(), cards: (0..<30).map { due("c\($0)", at: yesterday) })
        var study = StudySession(deck: unfinished, at: yesterday, calendar: calendar, random: SeededRandom(seed: 1), reviewMode: .revealed)
        for _ in 0..<8 {
            let id = study.session.currentCardID!
            let card = study.review(.good, of: unfinished.card(withID: id)!, with: unfinished.learningOptions, at: yesterday, calendar: calendar)!
            unfinished.cards[unfinished.index(of: id)!] = card
        }
        #expect(evaluate([unfinished], at: now).streak == Streak(days: 0, repairReviews: nil))
    }

    @Test func decksAddUp() throws {
        var first = try Deck(learningOptions: options(), cards: (0..<30).map { due("a\($0)", at: now) })
        let second = try Deck(learningOptions: options(), cards: (0..<5).map { due("b\($0)", at: now) })
        // Together the plan is 35 cards: the goal is 20 whichever deck the reviews are in.
        #expect(evaluate([first, second]).ring == DailyRing(reviews: 0, goal: 20))
        reviewPlan(of: &first, at: now)
        let progress = evaluate([first, second])
        #expect(progress.ring == DailyRing(reviews: 30, goal: 20))
        #expect(progress.streak.days == 1)
        // One deck alone is a smaller picture.
        #expect(evaluate([second]).ring == DailyRing(reviews: 0, goal: 5))
    }

    @Test func aReviewAtThreeFiftyNineBelongsToTheStudyDayBefore() throws {
        // 2026-10-06 03:59:59 and 04:00:00 in Berlin.
        let before = calendar.start(ofDay: today + 1).addingTimeInterval(-1)
        let after = calendar.start(ofDay: today + 1)
        var card = Card(question: "q", answer: "a")
        card.log = (0..<25).map { _ in ReviewLogEntry(date: before, grade: .good) } + [ReviewLogEntry(date: after, grade: .good)]
        card.learningState = LearningState(phase: .review, stability: 30, difficulty: 5, lastReview: after, due: after.addingTimeInterval(30 * 86400), reviews: 26)
        let deck = try Deck(learningOptions: options(), cards: [card])
        // Just before four the day is still 2026-10-05, which has the goal met.
        let evening = evaluate([deck], at: before)
        #expect(evening.ring.reviews == 25)
        #expect(evening.ring.laps == 1)
        // A second later it is the next day: one review of it, which is all its plan asks, so yesterday and
        // today are both in the streak.
        let morning = evaluate([deck], at: after)
        #expect(morning.ring == DailyRing(reviews: 1, goal: 1))
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
