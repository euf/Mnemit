import Foundation
import Testing

@testable import VocabCore

/// The ring and the streak, from the review logs alone.
struct DailyGoalTests {
    @Test func theGoalIsThePlanInCardsWhateverHappensToItAfter() {
        #expect(DailyGoal.goal(done: 0, owed: 8, plan: 8) == 8)
        #expect(DailyGoal.goal(done: 0, owed: 60, plan: 60) == 60)
        // A card done leaves the plan: the goal stays while the plan is worked off.
        #expect(DailyGoal.goal(done: 3, owed: 5, plan: 8) == 8)
        #expect(DailyGoal.goal(done: 4, owed: 4, plan: 8) == 8)
        // A card that is asked again is still owed and not done: nothing moves the goal.
        #expect(DailyGoal.goal(done: 4, owed: 5, plan: 8) == 8)
        // Cards added later are owed, too, and are no part of the plan.
        #expect(DailyGoal.goal(done: 8, owed: 5, plan: 8) == 8)
        // The plan done: the goal is the plan, whatever is done beyond it.
        #expect(DailyGoal.goal(done: 8, owed: 0, plan: 8) == 8)
        #expect(DailyGoal.goal(done: 45, owed: 0, plan: 8) == 8)
    }

    /// A day that began with nothing planned (a first deck filled in the afternoon, a day with
    /// nothing due) takes the plan as it stands: the first day gets a goal, not laps.
    @Test func anEmptyPlanAtDayStartTakesThePlanAsItStands() {
        #expect(DailyGoal.goal(done: 0, owed: 0, plan: 0) == 0)
        #expect(DailyGoal.goal(done: 12, owed: 0, plan: 0) == 12)
        #expect(DailyGoal.goal(done: 0, owed: 10, plan: 0) == 10)
        #expect(DailyGoal.goal(done: 4, owed: 6, plan: 0) == 10)
    }

    @Test func aPlanThatIsDoneWithFewerCardsThanPlannedIsMetAtThoseCards() {
        // Cards of the plan that were deleted or suspended during the day.
        #expect(DailyGoal.goal(done: 3, owed: 0, plan: 8) == 3)
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
        var ring = DailyRing(done: 5, goal: 20)
        #expect(ring.fraction == 0.25)
        #expect(!ring.isGoalMet)
        #expect(ring.laps == 0)
        ring.done = 20
        #expect(ring.isGoalMet)
        #expect(ring.laps == 1)
        ring.done = 45
        #expect(ring.fraction == 2.25)
        #expect(ring.laps == 2)
    }

    @Test func aRingWithoutAGoalIsMetAndCountsEachCardAsALap() {
        #expect(DailyRing(done: 0, goal: 0).isGoalMet)
        #expect(DailyRing(done: 0, goal: 0).fraction == 0)
        #expect(DailyRing(done: 0, goal: 0).laps == 0)
        let ring = DailyRing(done: 3, goal: 0)
        #expect(ring.isGoalMet)
        #expect(ring.laps == 3)
        #expect(DailyRing(done: -2, goal: -1) == DailyRing(done: 0, goal: 0))
    }

    /// Reviews `seconds` after a start, of cards that were new when their study day began or of others.
    func reviews(_ seconds: [Double], new isNew: Bool = false) -> [DailyGoal.PacedReview] {
        seconds.map { (Date(timeIntervalSince1970: 1_791_216_000 + $0), isNew, nil, true) }
    }

    /// A review at `start` and one after each of `gaps`, seconds apart.
    func spaced(_ gaps: [Double], new isNew: Bool = false, from start: Double = 0) -> [DailyGoal.PacedReview] {
        var times = [start]
        for gap in gaps {
            times.append(times[times.count - 1] + gap)
        }
        return reviews(times, new: isNew)
    }

    /// SplitMix64: the same numbers on every run.
    struct SeededGenerator: RandomNumberGenerator {
        var state: UInt64

        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
    }

    /// `count` gaps whose logarithms are normal with mean `mu` and deviation `sigma` (Box-Muller).
    func lognormalGaps(_ count: Int, mu: Double, sigma: Double, seed: UInt64 = 7) -> [Double] {
        var generator = SeededGenerator(state: seed)
        return (0..<count).map { _ in
            let radius = (-2 * log(Double.random(in: Double.ulpOfOne..<1, using: &generator))).squareRoot()
            return exp(mu + sigma * radius * cos(2 * .pi * Double.random(in: 0..<1, using: &generator)))
        }
    }

    /// Reviews of `durations` seconds each, `spacing` seconds apart, of new cards or of others.
    func timed(_ durations: [Double], spacing: Double = 100, new isNew: Bool = false, from start: Double = 0) -> [DailyGoal.PacedReview] {
        durations.enumerated().map { (Date(timeIntervalSince1970: 1_791_216_000 + start + Double($0.offset) * spacing), isNew, .seconds($0.element), true) }
    }

    /// The other price of a day of `gaps`, one review each and one done card for each review.
    func otherPrice(_ gaps: [Double]) -> Double {
        DailyGoal.pace(days: [spaced(gaps)], newDone: 0, otherDone: gaps.count + 1).otherCard
    }

    @Test func aSteadyLearnerTakesTheirGapPerReview() {
        let gaps = [Double](repeating: 5, count: 30)
        #expect(abs(otherPrice(gaps) - 5) < 1e-9)
        // The reviews need not come sorted.
        let shuffled = Array(spaced(gaps).reversed())
        #expect(abs(DailyGoal.pace(days: [shuffled], newDone: 0, otherDone: 31).otherCard - 5) < 1e-9)
        // The other category has nothing to price by: its fallback.
        #expect(DailyGoal.pace(days: [spaced(gaps)], newDone: 31, otherDone: 31).newCard == DailyGoal.fallbackNewCardSeconds)
    }

    @Test func breaksDoNotMoveThePrice() {
        // A tenth of the gaps are ten-minute breaks, in a steady learner and in one whose gaps vary.
        func withBreaks(_ gaps: [Double]) -> [Double] {
            gaps.enumerated().map { $0.offset % 10 == 9 ? 600 : $0.element }
        }
        let steady = [Double](repeating: 5, count: 400)
        #expect(abs(otherPrice(withBreaks(steady)) - 5) < 1e-9)
        let varied = lognormalGaps(400, mu: log(5), sigma: 0.3)
        let clean = otherPrice(varied)
        #expect(abs(clean - 5) < 0.5)
        #expect(abs(otherPrice(withBreaks(varied)) / clean - 1) < 0.1)
    }

    @Test func aThirdOfTheGapsBeingBreaksOfAnHourLeavesThePriceWithinATenth() {
        // 30 % of the gaps are breaks of an hour. The median is then the 0.5 / 0.7 quantile of the gaps
        // between cards, not their median, which a spread of 0.15 in the logarithm moves by 9 %.
        let gaps = lognormalGaps(400, mu: log(9), sigma: 0.15)
        let withBreaks = gaps.enumerated().map { $0.offset % 10 < 3 ? 3600 : $0.element }
        let clean = otherPrice(gaps)
        #expect(abs(clean - 9) < 0.5)
        #expect(abs(otherPrice(withBreaks) / clean - 1) < 0.1)
        // The mean of the lognormal that these gaps follow, which is what the median replaced, runs away.
        let logs = withBreaks.map { log($0) }.sorted()
        let iqr = logs[logs.count * 3 / 4] - logs[logs.count / 4]
        #expect(exp(logs[logs.count / 2] + pow(iqr / 1.349, 2) / 2) > 3 * clean)
    }

    @Test func theGapPriceIsTheMedianGapNotTheMeanOfTheirLognormal() {
        let mu = log(6.0)
        let sigma = 0.6
        let price = otherPrice(lognormalGaps(400, mu: mu, sigma: sigma))
        #expect(abs(price / exp(mu) - 1) < 0.1)
    }

    @Test func theMeanOfLognormalDurationsIsFoundWithoutTheirTail() {
        let mu = log(6.0)
        let sigma = 0.6
        let durations = lognormalGaps(400, mu: mu, sigma: sigma)
        let price = DailyGoal.pace(days: [timed(durations)], newDone: 0, otherDone: 400).otherCard
        let mean = exp(mu + sigma * sigma / 2)
        #expect(abs(price / mean - 1) < 0.1)
    }

    @Test func aReviewIsPricedTimesTheReviewsEachDoneCardTook() {
        let gaps = [Double](repeating: 5, count: 299)
        // 300 reviews of 5 s: a card done by each is 5 s, a card done by three is 15 s.
        let news = spaced(gaps, new: true)
        #expect(abs(DailyGoal.pace(days: [news], newDone: 300, otherDone: 0).newCard - 5) < 1e-9)
        #expect(abs(DailyGoal.pace(days: [news], newDone: 100, otherDone: 0).newCard - 15) < 1e-9)
        // A hundred review cards, one review each: 5 s. Twenty of them went wrong and took a review
        // more, and the same hundred done cards cost 6 s.
        let others = [Double](repeating: 5, count: 99)
        #expect(abs(DailyGoal.pace(days: [spaced(others)], newDone: 0, otherDone: 100).otherCard - 5) < 1e-9)
        let withAgains = [Double](repeating: 5, count: 119)
        #expect(abs(DailyGoal.pace(days: [spaced(withAgains)], newDone: 0, otherDone: 100).otherCard - 6) < 1e-9)
    }

    @Test func reviewsOfCardsNotDoneThatDayDoNotChangeTheReviewsPerDoneCard() {
        // Twenty new cards done by two reviews each, 5 s apart: 10 s a card.
        let done = spaced([Double](repeating: 5, count: 39), new: true)
        #expect(abs(DailyGoal.pace(days: [done], newDone: 20, otherDone: 0).newCard - 10) < 1e-9)
        // Fifteen new cards begun and left open, six reviews each (the Agains among them), at the same 5 s
        // a review: they are in no price, as their cards are in none.
        let open = spaced([Double](repeating: 5, count: 90), new: true, from: 1000).map { (date: $0.date, isNew: true, duration: $0.duration, isDone: false) }
        #expect(abs(DailyGoal.pace(days: [done + open], newDone: 20, otherDone: 0).newCard - 10) < 1e-9)
        // The same reviews of cards that were done would price a card higher.
        let doneToo = open.map { (date: $0.date, isNew: $0.isNew, duration: $0.duration, isDone: true) }
        #expect(abs(DailyGoal.pace(days: [done + doneToo], newDone: 35, otherDone: 0).newCard - 5 * 131.0 / 35) < 1e-9)
    }

    @Test func theFirstReviewOfEachDayIsAReviewWithoutAGap() {
        // Two days of 11 reviews, 5 s apart: 20 gaps and 22 reviews over 11 done cards.
        let day = spaced([Double](repeating: 5, count: 10))
        #expect(abs(DailyGoal.pace(days: [day, day], newDone: 0, otherDone: 11).otherCard - 10) < 1e-9)
    }

    @Test func aGapIsTheTimeOfTheCardOfTheLaterReview() {
        // An other review and a new one by turns, the new ones 10 s after the other and the
        // others 6 s after the new: the gaps before a review are its card's.
        var times: [Double] = [0]
        for _ in 0..<25 { times += [times.last! + 10, times.last! + 16] }
        let day: [DailyGoal.PacedReview] = reviews(times).enumerated().map { (date: $0.element.date, isNew: $0.offset % 2 == 1, duration: nil, isDone: true) }
        // 25 new reviews of 10 s, one per done card; 26 others of 6 s, the first with no gap, two per done card.
        let pace = DailyGoal.pace(days: [day], newDone: 25, otherDone: 13)
        #expect(abs(pace.newCard - 10) < 1e-9)
        #expect(abs(pace.otherCard - 12) < 1e-9)
    }

    @Test func twoDaysAreNotOneLongGap() {
        // Two reviews a minute apart on different days are no work between them.
        let pace = DailyGoal.pace(days: [reviews([0]), reviews([60])], newDone: 20, otherDone: 20)
        #expect(pace == Pace())
    }

    @Test func eachKindFallsBackWhenItHasFewerThanTwentyGapsOrTenDoneCards() {
        #expect(DailyGoal.fallbackNewCardSeconds == 30)
        #expect(DailyGoal.fallbackOtherCardSeconds == 10)
        #expect(Pace() == Pace(newCard: 30, otherCard: 10))
        // 20 gaps of 10 s of new cards, 20 gaps of 4 s of others: 21 reviews each.
        let day = spaced([Double](repeating: 10, count: 20), new: true) + spaced([Double](repeating: 4, count: 20), from: 1000)
        func pace(_ newDone: Int, _ otherDone: Int) -> Pace {
            let pace = DailyGoal.pace(days: [day], newDone: newDone, otherDone: otherDone)
            return Pace(newCard: (pace.newCard * 1e6).rounded() / 1e6, otherCard: (pace.otherCard * 1e6).rounded() / 1e6)
        }
        // The first review of the other kind has a gap of its own, from the last new one: 20 gaps of 4 s and one of 800 s.
        #expect(pace(21, 21) == Pace(newCard: 10, otherCard: 4))
        // 21 reviews over 10 done cards.
        #expect(pace(10, 10) == Pace(newCard: 21, otherCard: 8.4))
        #expect(pace(9, 10) == Pace(newCard: 30, otherCard: 8.4))
        #expect(pace(10, 9) == Pace(newCard: 21, otherCard: 10))
        #expect(pace(0, 0) == Pace())
        #expect(DailyGoal.pace(days: [], newDone: 25, otherDone: 25) == Pace())
        // One gap short of twenty in a kind with plenty of cards: its fallback.
        let short = spaced([Double](repeating: 10, count: 19), new: true)
        #expect(DailyGoal.pace(days: [short], newDone: 40, otherDone: 40) == Pace())
        // Enough cards but no time between the reviews of a kind: its fallback, too.
        #expect(DailyGoal.pace(days: [reviews([0, 500, 1000], new: true)], newDone: 40, otherDone: 40) == Pace())
    }

    @Test func durationsOfExactlyFourSecondsPriceAReviewAtFour() {
        // The gaps between the reviews are 100 s: the price comes from the durations, not from them.
        let day = timed([Double](repeating: 4, count: 20))
        #expect(abs(DailyGoal.pace(days: [day], newDone: 0, otherDone: 20).otherCard - 4) < 1e-9)
        // Twice the reviews over the same cards: twice the price.
        #expect(abs(DailyGoal.pace(days: [day], newDone: 0, otherDone: 10).otherCard - 8) < 1e-9)
        // Each kind has its own.
        let both = timed([Double](repeating: 3, count: 20), new: true) + timed([Double](repeating: 6, count: 20), new: false, from: 5000)
        let pace = DailyGoal.pace(days: [both], newDone: 20, otherDone: 20)
        #expect(abs(pace.newCard - 3) < 1e-9 && abs(pace.otherCard - 6) < 1e-9)
    }

    @Test func fewerThanTwentyDurationsLeaveThePriceToTheGaps() {
        // 25 reviews 5 s apart: 24 gaps of 5 s. Nineteen of them have a duration of 2 s, which is too few.
        let day = spaced([Double](repeating: 5, count: 24)).enumerated().map { (date: $0.element.date, isNew: false, duration: $0.offset < 19 ? Duration.seconds(2) : nil, isDone: true) }
        #expect(abs(DailyGoal.pace(days: [day], newDone: 0, otherDone: 25).otherCard - 5) < 1e-9)
        // With a twentieth, the durations take over; the reviews without one stay in the count of reviews.
        let more = day.enumerated().map { (date: $0.element.date, isNew: false, duration: $0.offset < 20 ? Duration.seconds(2) : nil, isDone: true) }
        #expect(abs(DailyGoal.pace(days: [more], newDone: 0, otherDone: 25).otherCard - 2) < 1e-9)
        // Durations don't excuse a kind with fewer than ten done cards.
        #expect(DailyGoal.pace(days: [timed([Double](repeating: 4, count: 30))], newDone: 0, otherDone: 9) == Pace())
    }

    @Test func oneTwentyMinuteDurationAmongFortyMovesThePriceByLessThanATenth() {
        let durations = lognormalGaps(40, mu: log(4), sigma: 0.4)
        let usual = DailyGoal.pace(days: [timed(durations)], newDone: 0, otherDone: 40).otherCard
        #expect(abs(usual - 4 * exp(0.4 * 0.4 / 2)) < 1)
        for index in [0, 17, 39] {
            var withBreak = durations
            withBreak[index] = 1200
            let price = DailyGoal.pace(days: [timed(withBreak)], newDone: 0, otherDone: 40).otherCard
            #expect(abs(price / usual - 1) < 0.1)
        }
        // Steady learner: no move at all.
        var steady = [Double](repeating: 4, count: 40)
        steady[20] = 1200
        #expect(abs(DailyGoal.pace(days: [timed(steady)], newDone: 0, otherDone: 40).otherCard - 4) < 1e-9)
    }

    @Test func minutesLeftRoundUpAndASliverIsUnderAMinute() {
        #expect(DailyGoal.minutesLeft(cards: 0, secondsPerCard: 20) == nil)
        #expect(DailyGoal.minutesLeft(cards: -4, secondsPerCard: 20) == nil)
        // Under a minute is 0, which reads "< 1 min".
        #expect(DailyGoal.minutesLeft(cards: 1, secondsPerCard: 20) == 0)
        #expect(DailyGoal.minutesLeft(cards: 2, secondsPerCard: 29.5) == 0)
        #expect(DailyGoal.minutesLeft(cards: 3, secondsPerCard: 20) == 1)
        #expect(DailyGoal.minutesLeft(cards: 4, secondsPerCard: 20) == 2)
        #expect(DailyGoal.minutesLeft(cards: 74, secondsPerCard: 5) == 7)
        #expect(DailyGoal.minutesLeft(cards: 74, secondsPerCard: 5.2) == 7)
        #expect(DailyGoal.minutesLeft(cards: 74, secondsPerCard: 5.8) == 8)
        #expect(DailyGoal.minutesLeft(cards: 300, secondsPerCard: 20) == 100)
    }

    @Test func theTimeLeftPricesNewCardsAndOthersEachAtItsOwnPace() {
        let pace = Pace(newCard: 30, otherCard: 10)
        #expect(DailyGoal.minutesLeft(newCards: 0, otherCards: 0, pace: pace) == nil)
        #expect(DailyGoal.minutesLeft(newCards: 0, otherCards: 5, pace: pace) == 0)
        // 3 × 30 s + 4 × 10 s = 130 s: three minutes, where all seven at the new price take four
        // and all seven at the other price take two.
        #expect(DailyGoal.minutesLeft(newCards: 3, otherCards: 4, pace: pace) == 3)
        #expect(DailyGoal.minutesLeft(newCards: 7, otherCards: 0, pace: pace) == 4)
        #expect(DailyGoal.minutesLeft(newCards: 0, otherCards: 7, pace: pace) == 2)
        // 20 × 30 s + 60 × 10 s = 1200 s exactly, 20 minutes.
        #expect(DailyGoal.minutesLeft(newCards: 20, otherCards: 60, pace: pace) == 20)
        #expect(pace.seconds(newCards: 3, otherCards: 4) == 130)
    }

    @Test func oneEffectivePriceForTheWidgetGivesTheMinutesOfTheSum() {
        let pace = Pace(newCard: 30, otherCard: 10)
        let effective = pace.secondsPerCard(newCards: 3, otherCards: 4)
        #expect(abs(effective - 130.0 / 7) < 1e-12)
        // No cards left: the price of the others.
        #expect(pace.secondsPerCard(newCards: 0, otherCards: 0) == 10)
        // 26 new and 12 other cards take 900 s, 15 minutes. 38 × (900 / 38) is a hair over 900 in
        // floating point, which a plain round-up would turn into 16.
        let widget = DailyGoal.minutesLeft(cards: 38, secondsPerCard: pace.secondsPerCard(newCards: 26, otherCards: 12))
        #expect(widget == 15)
        #expect(widget == DailyGoal.minutesLeft(newCards: 26, otherCards: 12, pace: pace))
    }
}

struct StreakTests {
    /// By default every day is judged by its plan alone: the days of these tests are numbered from 100.
    /// `owed` is what each day left of its plan: a day with cards owed missed its first round and left its ring
    /// open, a day without has both done.
    func streak(_ reviews: [Int: Int], today: Int, planRuleStart: Int = .min, owed: [Int: Int] = [:]) -> Streak {
        Streak.evaluate(
            reviews: reviews, today: today, planRuleStart: planRuleStart, isKept: { (owed[$0] ?? 0) == 0 }, isClosed: { (owed[$0] ?? 0) == 0 },
            repairCards: owed[today] ?? 0)
    }

    /// The days whose first round was done (`kept`) and whose ring was closed (`closed`, a subset).
    func streak(_ reviews: [Int: Int], today: Int, kept: Set<Int>, closed: Set<Int>, repairCards: Int = 0) -> Streak {
        Streak.evaluate(reviews: reviews, today: today, planRuleStart: .min, isKept: { kept.contains($0) }, isClosed: { closed.contains($0) }, repairCards: repairCards)
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

    @Test func aDayBeforeThePlanRuleCountsWithASingleAnswerAndTheSameDayAfterItDoesNot() {
        // 101 and 102 had answers and left cards of their plan over.
        let days = [100: 20, 101: 3, 102: 1]
        let owed = [101: 4, 102: 2]
        // Before the cutover they count, as under the rule of a fixed number of answers a day.
        #expect(streak(days, today: 103, planRuleStart: 103, owed: owed) == Streak(days: 4, repairCards: nil))
        // From the cutover on the same days are two missed days in a row, and break the streak.
        #expect(streak(days, today: 103, planRuleStart: 101, owed: owed) == Streak(days: 1, repairCards: nil))
        #expect(streak(days, today: 103, planRuleStart: .min, owed: owed) == Streak(days: 1, repairCards: nil))
        // The cutover day itself is already judged by its plan: 101 counts, 102 is missed once and today repairs it.
        #expect(streak(days, today: 103, planRuleStart: 102, owed: owed) == Streak(days: 4, repairCards: nil))
        // Today counts too before the cutover, once it has an answer.
        #expect(streak([100: 5, 101: 1], today: 101, planRuleStart: 102, owed: [101: 3]) == Streak(days: 2, repairCards: nil))
        #expect(streak([100: 5, 101: 1], today: 101, planRuleStart: 101, owed: [101: 3]) == Streak(days: 1, repairCards: nil))
    }

    @Test func aDayBeforeThePlanRuleWithoutAnAnswerIsJudgedByItsPlanAndTheLegacyDaysAreNotAskedAbout() {
        // 101 had no answer and owed something: it is missed, and 102 repairs it.
        #expect(streak([100: 5, 102: 5], today: 103, planRuleStart: 200, owed: [101: 2]) == Streak(days: 4, repairCards: nil))
        var asked: [Int] = []
        _ = Streak.evaluate(
            reviews: [100: 5, 101: 5], today: 103, planRuleStart: 102, isKept: { asked.append($0); return true }, isClosed: { asked.append($0); return true }, repairCards: 0)
        // A day with an answer before the cutover isn't looked at: it counts as it is.
        #expect(asked == [102, 103])
    }

    @Test func theCutoverIsTheStudyDayOfTheTwentyThirdOfOctober() {
        #expect(DailyGoal.planRuleStart == CivilDate(year: 2026, month: 10, day: 23).dayNumber)
        let calendar = StudyCalendar.testing
        // A study day starts at 04:00: the 23rd at 03:59 still belongs to the 22nd.
        let start = calendar.start(ofDay: DailyGoal.planRuleStart)
        #expect(calendar.dayNumber(for: start) == DailyGoal.planRuleStart)
        #expect(calendar.dayNumber(for: start.addingTimeInterval(-1)) == DailyGoal.planRuleStart - 1)
    }

    @Test func everyDayFromTheFirstReviewToTodayIsJudged() {
        var asked: [Int] = []
        _ = Streak.evaluate(
            reviews: [100: 5, 103: 5, 90: 0], today: 105, planRuleStart: .min, isKept: { asked.append($0); return true }, isClosed: { asked.append($0); return true },
            repairCards: 0)
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

    @Test func aDayCountsOnItsFirstRoundWithTheRingStillOpen() {
        let days = Dictionary(uniqueKeysWithValues: (100...102).map { ($0, 12) })
        #expect(streak(days, today: 103, kept: [100, 101, 102, 103], closed: []) == Streak(days: 4, repairCards: nil))
        // Today's first round is not done yet: the streak is as it was, not broken.
        #expect(streak(days, today: 103, kept: [100, 101, 102], closed: []) == Streak(days: 3, repairCards: nil))
    }

    @Test func aMissedDayIsRepairedOnlyByTheNextDayClosingItsRing() {
        // 101 is missed. 102 is closed: both count.
        #expect(streak([100: 5, 102: 5], today: 103, kept: [100, 102, 103], closed: [102]) == Streak(days: 4, repairCards: nil))
        // 102 only did its first round: 101 stays missed and the streak starts anew with 102.
        #expect(streak([100: 5, 102: 5], today: 103, kept: [100, 102, 103], closed: []) == Streak(days: 2, repairCards: nil))
    }

    @Test func todayRepairsYesterdayOnlyOnceItsRingIsClosed() {
        let days = [100: 5, 101: 5]
        // 102 is missed; today's first round is done, the ring is not: the old streak stands, with the cards that close it.
        #expect(streak(days, today: 103, kept: [100, 101, 103], closed: [], repairCards: 7) == Streak(days: 2, repairCards: 7))
        #expect(streak(days, today: 103, kept: [100, 101], closed: [], repairCards: 9) == Streak(days: 2, repairCards: 9))
        #expect(streak(days, today: 103, kept: [100, 101, 103], closed: [103]) == Streak(days: 4, repairCards: nil))
    }

    @Test func twoMissedDaysEndTheStreakWhateverCloses() {
        let days = [100: 5, 101: 5]
        #expect(streak(days, today: 104, kept: [100, 101, 104], closed: [104]) == Streak(days: 1, repairCards: nil))
        #expect(streak(days, today: 104, kept: [100, 101], closed: []) == Streak(days: 0, repairCards: nil))
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

    /// A card that was added before the study day of `now` began, so its plan holds it.
    func new(_ question: String) -> Card {
        Card(question: question, answer: question, created: calendar.start(ofDay: today).addingTimeInterval(-3600))
    }

    /// Grades the card at `index` of `deck` with each of `grades` in turn at `date`, as a stream does.
    func grade(_ grades: [Grade], at index: Int, of deck: inout Deck, on date: Date? = nil) {
        let scheduler = Scheduler(learningOptions: deck.learningOptions, calendar: calendar)
        var random = SeededRandom(seed: 1)
        for grade in grades {
            deck.cards[index] = scheduler.review(deck.cards[index], grade: grade, at: date ?? now, mode: .revealed, using: &random)
        }
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

    /// By default every day is judged by its plan alone, whatever date the test is set on.
    func evaluate(_ decks: [Deck], at date: Date? = nil, planRuleStart: Int = .min) -> DailyProgress {
        DailyProgress.evaluate(decks.map { DeckActivity(deck: $0, calendar: calendar) }, at: date ?? now, calendar: calendar, planRuleStart: planRuleStart)
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

    /// A card learned by `grades` at `dates`, as the scheduler replays its log.
    func answered(_ question: String, _ grades: [Grade], at dates: [Date], options: LearningOptions? = nil, duration: Duration? = nil) -> Card {
        let log = zip(grades, dates).map { ReviewLogEntry(date: $1, grade: $0, mode: .revealed, duration: duration) }
        return Scheduler(learningOptions: options ?? self.options(), calendar: calendar).replaying(log, of: Card(question: question, answer: question))
    }

    /// The study day `days` before today at `hour`:`minute`.
    func at(_ days: Int, _ hour: Double, _ minute: Double = 0) -> Date {
        calendar.start(ofDay: today - days).addingTimeInterval(hour * 3600 + minute * 60)
    }

    @Test func aNewCardWithThreeAnswersIsOneDoneCard() throws {
        var options = options()
        options.steps = 3
        let card = answered("n", [.good, .good, .good], at: [at(0, 10), at(0, 10, 1), at(0, 10, 2)], options: options)
        let deck = try Deck(learningOptions: options, cards: [card, Card(question: "p", answer: "p")])
        let pace = DeckActivity(deck: deck, calendar: calendar).paceLog(at: now, calendar: calendar)
        #expect(pace.done == 1)
        // The three reviews and the done card of a card that was new when the day began are new.
        #expect(pace.newDone == 1 && pace.otherDone == 0)
        #expect(pace.days[today]?.map(\.isNew) == [true, true, true])
        #expect(pace.days[today]?.map(\.isDone) == [true, true, true])
    }

    @Test func aCardStillInLearningAtTheDaysEndIsNotDone() throws {
        var options = options()
        options.steps = 3
        let card = answered("n", [.good, .good], at: [at(0, 10), at(0, 10, 1)], options: options)
        let deck = try Deck(learningOptions: options, cards: [card])
        let pace = DeckActivity(deck: deck, calendar: calendar).paceLog(at: now, calendar: calendar)
        #expect(pace.done == 0)
        #expect(pace.days[today]?.count == 2)
        // Its reviews are in the log for the time between them, but are those of no done card.
        #expect(pace.days[today]?.map(\.isDone) == [false, false])
    }

    @Test func theReviewsOfAnOpenCardAreNotThoseOfADoneCardEvenWithManyAgains() throws {
        var options = options()
        options.steps = 3
        // Ten new cards, each learned by three Goods 8 s apart, and ten more begun with Again, Again, Again, Good
        // and left in their steps. A card of the first ten is done at its third review.
        let morning = at(0, 9)
        let doneCards = (0..<10).map { index in
            let first = morning.addingTimeInterval(Double(index) * 100)
            return answered("d\(index)", [.good, .good, .good], at: [first, first.addingTimeInterval(8), first.addingTimeInterval(16)], options: options)
        }
        let openCards = (0..<10).map { index in
            let first = morning.addingTimeInterval(2000 + Double(index) * 100)
            return answered("o\(index)", [.again, .again, .again, .good], at: (0..<4).map { first.addingTimeInterval(Double($0) * 8) }, options: options)
        }
        let all = try Deck(learningOptions: options, cards: doneCards + openCards)
        let log = DeckActivity(deck: all, calendar: calendar).paceLog(at: now, calendar: calendar)
        #expect(log.newDone == 10 && log.otherDone == 0)
        let reviews = log.days[today] ?? []
        #expect(reviews.count == 70)
        // Only the thirty reviews of the done cards are those of a done card: three each, whatever else was begun.
        #expect(reviews.filter(\.isDone).count == 30)
        let alone = DeckActivity(deck: try Deck(learningOptions: options, cards: doneCards), calendar: calendar).paceLog(at: now, calendar: calendar)
        #expect(alone.newDone == 10 && alone.days[today]?.count == 30)
        #expect(alone.days[today]?.allSatisfy(\.isDone) == true)
    }

    @Test func aCardIsDoneOnEachDayItWasLetGoAndTheWindowIsTheSevenDaysBeforeToday() throws {
        // Learned three days ago (done that day), reviewed again today (done today): the later answer
        // doesn't take the earlier day's card away.
        let again = answered("a", [.good, .good, .good], at: [at(3, 10), at(3, 10, 1), at(0, 9)])
        // A card done on the seventh day before today is in the window, one on the eighth is not.
        let edge = answered("e", [.good, .good], at: [at(7, 10), at(7, 10, 1)])
        let outside = answered("o", [.good, .good], at: [at(8, 10), at(8, 10, 1)])
        let deck = try Deck(learningOptions: options(), cards: [again, edge, outside])
        let pace = DeckActivity(deck: deck, calendar: calendar).paceLog(at: now, calendar: calendar)
        #expect(pace.done == 3)
        #expect(Set(pace.days.keys) == [today - 7, today - 3, today])
        // A card is new on the day of its first review and not after: learned three days ago it is
        // done as a new card, and reviewed today as another.
        #expect(pace.newDone == 2 && pace.otherDone == 1)
        #expect(pace.days[today - 3]?.map(\.isNew) == [true, true])
        #expect(pace.days[today]?.map(\.isNew) == [false])
    }

    @Test func anAgainOnAReviewCardAndItsRelearningAreOthers() throws {
        // Learned a month ago, forgotten today and relearned by two Goods 12 s apart.
        let card = answered(
            "r", [.good, .good, .again, .good, .good], at: [at(30, 10), at(30, 10, 1), at(0, 9), at(0, 9, 0.2), at(0, 9, 0.4)])
        let deck = try Deck(learningOptions: options(), cards: [card])
        let log = DeckActivity(deck: deck, calendar: calendar).paceLog(at: now, calendar: calendar)
        #expect(log.days[today]?.map(\.isNew) == [false, false, false])
        #expect(log.newDone == 0 && log.otherDone == 1)
    }

    @Test func aCardWithoutItsFirstReviewsInTheLogCountsAsDoneOnEachDayAnswered() throws {
        var card = answered("c", [.good, .good], at: [at(2, 10), at(2, 10, 1)])
        card.log.removeFirst()
        let deck = try Deck(learningOptions: options(), cards: [card])
        #expect(!card.hasCompleteLog)
        let pace = DeckActivity(deck: deck, calendar: calendar).paceLog(at: now, calendar: calendar)
        // Its log can't say that the card was new: the card is another.
        #expect(pace.done == 1)
        #expect(pace.newDone == 0 && pace.otherDone == 1)
    }

    @Test func theLearnersPaceIsPricedFromTheGapsAndTheDoneCardsOfAllDecks() throws {
        // Twenty-five new cards in two decks, each learned by two Goods ten seconds apart, the cards twenty seconds apart:
        // 49 gaps of 10 s, 50 reviews over 25 done cards: 10 s a review, two reviews a card.
        let cards = (0..<25).map { index in
            answered("c\(index)", [.good, .good], at: [at(0, 9).addingTimeInterval(Double(index) * 20), at(0, 9).addingTimeInterval(Double(index) * 20 + 10)])
        }
        let decks = [try Deck(learningOptions: options(), cards: Array(cards[..<9])), try Deck(learningOptions: options(), cards: Array(cards[9...]))]
        let progress = evaluate(decks)
        #expect(abs(progress.pace.newCard - 20) < 1e-9)
        // No other card was done: its fallback.
        #expect(progress.pace.otherCard == DailyGoal.fallbackOtherCardSeconds)
        // Nothing is due, no cards are left and no time is wanted.
        #expect(progress.cardsLeft == 0)
        #expect(progress.minutesLeft == nil)
        // One deck alone has too few cards done and too few gaps (16 of them are in the other): the fallbacks.
        #expect(evaluate([decks[0]]).pace == Pace())
    }

    @Test func theLoggedDurationsPriceThePaceInsteadOfTheGaps() throws {
        // The same day as above, with 4 s logged for every review: the cards are 20 s apart, but a review took 4 s.
        let cards = (0..<25).map { index in
            answered("c\(index)", [.good, .good], at: [at(0, 9).addingTimeInterval(Double(index) * 20), at(0, 9).addingTimeInterval(Double(index) * 20 + 10)], duration: .seconds(4))
        }
        let deck = try Deck(learningOptions: options(), cards: cards)
        let log = DeckActivity(deck: deck, calendar: calendar).paceLog(at: now, calendar: calendar)
        #expect(log.days[today]?.compactMap(\.duration) == [Duration](repeating: .seconds(4), count: 50))
        // 4 s a review, two reviews a card.
        #expect(abs(evaluate([deck]).pace.newCard - 8) < 1e-9)
    }

    @Test func newCardsAndOthersAreEachPricedFromTheirOwnGaps() throws {
        var options = options()
        options.steps = 3
        let morning = at(0, 9)
        let learnedLongAgo = [at(30, 10), at(30, 10, 1), at(30, 10, 2)]
        // A review card that goes wrong at 09:00:00 and stays in relearning: a first review with no
        // time before it, and no card done.
        var cards = [answered("lead", [.good, .good, .good, .again], at: learnedLongAgo + [morning], options: options)]
        // Twenty review cards, one Good each 6 s after the other: 20 gaps of 6 s, and 20 reviews over
        // 20 done cards: the review of the card in relearning is a review of no done card.
        cards += (0..<20).map { index in
            answered("r\(index)", [.good, .good, .good, .good], at: learnedLongAgo + [morning.addingTimeInterval(6 + 6 * Double(index))], options: options)
        }
        // Ten new cards of three Goods each, every review 8 s after the one before: 30 gaps of 8 s,
        // 30 reviews over 10 done cards.
        cards += (0..<10).map { index in
            let first = morning.addingTimeInterval(128 + 24 * Double(index))
            return answered("n\(index)", [.good, .good, .good], at: [first, first.addingTimeInterval(8), first.addingTimeInterval(16)], options: options)
        }
        let deck = try Deck(learningOptions: options, cards: cards)
        let log = DeckActivity(deck: deck, calendar: calendar).paceLog(at: now, calendar: calendar)
        #expect(log.newDone == 10 && log.otherDone == 20)
        let progress = evaluate([deck])
        #expect(abs(progress.pace.newCard - 24) < 1e-9)
        #expect(abs(progress.pace.otherCard - 6) < 1e-9)
        // The card in relearning is the one card left, and it was not new when the day began.
        #expect(progress.cardsLeft == 1 && progress.newCardsLeft == 0)
        #expect(progress.minutesLeft == 0)
    }

    @Test func theMinutesLeftAreTheCardsOfThePlanStillOwedAtThePace() throws {
        // Seven review cards due today and no history to price a card by: 10 s each, 70 s, two minutes.
        let deck = try Deck(learningOptions: options(), cards: (0..<7).map { due("c\($0)", onDay: today) })
        var progress = evaluate([deck])
        #expect(progress.cardsLeft == 7 && progress.newCardsLeft == 0)
        #expect(progress.pace == Pace())
        #expect(progress.minutesLeft == 2)
        // One card left: under a minute.
        var worked = deck
        review(6, of: &worked, at: now)
        progress = evaluate([worked])
        #expect(progress.cardsLeft == 1)
        #expect(progress.minutesLeft == 0)
        reviewPlan(of: &worked, at: now)
        #expect(evaluate([worked]).minutesLeft == nil)
    }

    @Test func theTimeLeftPricesTheNewCardsAndTheOthersLeftEachByItsPace() throws {
        // Four new cards and three review cards: 4 × 30 s + 3 × 10 s = 150 s, three minutes.
        let deck = try Deck(learningOptions: options(), cards: (0..<4).map { new("n\($0)") } + (0..<3).map { due("c\($0)", onDay: today) })
        let progress = evaluate([deck])
        #expect(progress.cardsLeft == 7 && progress.newCardsLeft == 4 && progress.otherCardsLeft == 3)
        #expect(progress.minutesLeft == 3)
        // The widget's one price: the time left over the cards left; with none left, the price of the others.
        #expect(abs(progress.secondsPerCardLeft - 150.0 / 7) < 1e-12)
        var worked = deck
        reviewPlan(of: &worked, at: now)
        #expect(evaluate([worked]).cardsLeft == 0)
        #expect(evaluate([worked]).secondsPerCardLeft == DailyGoal.fallbackOtherCardSeconds)
    }

    @Test func aNewCardStartedTodayAndStillInLearningIsNewAndAnAgainIsNot() throws {
        // Four new cards and three review cards. An hour ago one new card got a Good, which leaves it in its
        // learning steps and due again, and a review card an Again, which leaves it in relearning.
        var deck = try Deck(learningOptions: options(), cards: (0..<4).map { new("n\($0)") } + (0..<3).map { due("c\($0)", onDay: today) })
        let hourAgo = now.addingTimeInterval(-3600)
        grade([.good], at: 0, of: &deck, on: hourAgo)
        grade([.again], at: 4, of: &deck, on: hourAgo)
        let counts = StudySession.counts(for: deck, at: now, calendar: calendar)
        #expect(counts.new == 3 && counts.learning == 2 && counts.review == 2)
        #expect(counts.learningFromNew == 1 && counts.newAtDayStart == 4)
        let progress = evaluate([deck])
        #expect(progress.cardsLeft == 7 && progress.newCardsLeft == 4 && progress.otherCardsLeft == 3)
        // 4 × 30 s + 3 × 10 s.
        #expect(progress.minutesLeft == 3)
        // Once through its steps the new card is done and no longer left.
        grade([.good], at: 0, of: &deck, on: now.addingTimeInterval(-1800))
        #expect(evaluate([deck]).newCardsLeft == 3)
    }

    @Test func theGoalIsThePlanInCardsAndTheRingFillsAsItIsWorkedOff() throws {
        var deck = try Deck(learningOptions: options(), cards: (0..<8).map { due("c\($0)", onDay: today) })
        var progress = evaluate([deck])
        #expect(progress.ring == DailyRing(done: 0, goal: 8))
        reviewPlan(of: &deck, at: now)
        progress = evaluate([deck])
        #expect(progress.ring == DailyRing(done: 8, goal: 8))
        #expect(progress.ring.isGoalMet)
        #expect(progress.streak.repairCards == nil)
    }

    @Test func aBigPlanKeepsAllItsCardsAndTheGoalIsTheOnesThatFitTheDayAndLapsComeAfterIt() throws {
        var deck = try Deck(learningOptions: options(), cards: (0..<50).map { due("c\($0)", onDay: today) })
        let progress = evaluate([deck])
        // Three rounds of two minutes hold 36 reviews of 10 s; the plan, and the cards left, are 50.
        #expect(progress.capacity == 3)
        #expect(progress.ring == DailyRing(done: 0, goal: 36))
        #expect(progress.cardsLeft == 50)
        reviewPlan(of: &deck, at: now)
        #expect(evaluate([deck]).ring == DailyRing(done: 50, goal: 36))
    }

    @Test func newCardsWithinTheLimitsAreInTheGoalOneCardEach() throws {
        var options = options()
        options.newCardsPerSession = 5
        var deck = try Deck(learningOptions: options, cards: (0..<4).map { due("c\($0)", onDay: today) } + (0..<30).map { new("n\($0)") })
        // Four reviews and five new cards: a new card takes two answers to leave the plan, but it is one card.
        #expect(StudySession.counts(for: deck, at: now, calendar: calendar).total == 9)
        #expect(evaluate([deck]).ring == DailyRing(done: 0, goal: 9))
        reviewPlan(of: &deck, at: now)
        #expect(evaluate([deck]).ring == DailyRing(done: 9, goal: 9))
        #expect(evaluate([deck]).ring.isGoalMet)
    }

    @Test func aReviewGradedHardGoodOrEasyIsDoneAtOnce() throws {
        var deck = try Deck(learningOptions: options(), cards: (0..<4).map { due("c\($0)", onDay: today) })
        var progress = evaluate([deck])
        #expect(progress.ring == DailyRing(done: 0, goal: 4))
        for (index, grade) in [Grade.hard, .good, .easy].enumerated() {
            self.grade([grade], at: index, of: &deck)
            progress = evaluate([deck])
            #expect(progress.ring == DailyRing(done: index + 1, goal: 4), "\(grade)")
            #expect(StudySession.counts(for: deck, at: now, calendar: calendar).total == 3 - index, "\(grade)")
        }
        #expect(!evaluate([deck]).ring.isGoalMet)
    }

    @Test func aNewCardIsDoneOnlyAfterItsLastLearningStep() throws {
        var options = options()
        options.steps = 3
        var deck = try Deck(learningOptions: options, cards: [new("n")])
        #expect(evaluate([deck]).ring == DailyRing(done: 0, goal: 1))
        for step in 1...2 {
            grade([.good], at: 0, of: &deck)
            // Not done, but on its way: each step is a third of the card.
            #expect(evaluate([deck]).ring == DailyRing(done: 0, goal: 1, underway: Double(step) / 3), "step \(step)")
            #expect(StudySession.counts(for: deck, at: now, calendar: calendar).total == 1, "step \(step)")
        }
        grade([.good], at: 0, of: &deck)
        #expect(evaluate([deck]).ring == DailyRing(done: 1, goal: 1))
        #expect(evaluate([deck]).ring.isGoalMet)
        #expect(StudySession.counts(for: deck, at: now, calendar: calendar).total == 0)
    }

    @Test func anAgainKeepsACardUndoneUntilItGraduatesAndNeverRaisesTheGoal() throws {
        var deck = try Deck(learningOptions: options(), cards: (0..<3).map { due("c\($0)", onDay: today) })
        grade([.good], at: 1, of: &deck)
        grade([.good], at: 2, of: &deck)
        #expect(evaluate([deck]).ring == DailyRing(done: 2, goal: 3))
        // Forgot: the card goes back to learning, and stays owed through every step of it.
        grade([.again], at: 0, of: &deck)
        #expect(evaluate([deck]).ring == DailyRing(done: 2, goal: 3))
        #expect(StudySession.counts(for: deck, at: now, calendar: calendar).total == 1)
        grade([.again], at: 0, of: &deck)
        grade([.good], at: 0, of: &deck)
        // Half of the card, as one of its two relearning steps is done.
        #expect(evaluate([deck]).ring == DailyRing(done: 2, goal: 3, underway: 0.5))
        #expect(!evaluate([deck]).ring.isGoalMet)
        // The last relearning step: FSRS lets the card go to another day, and the ring is closed.
        grade([.good], at: 0, of: &deck)
        #expect(evaluate([deck]).ring == DailyRing(done: 3, goal: 3))
        #expect(evaluate([deck]).ring.isGoalMet)
    }

    @Test func aCardCountsOnceHoweverManyAnswersItTook() throws {
        var deck = try Deck(learningOptions: options(), cards: [due("a", onDay: today), due("b", onDay: today)])
        grade([.again, .again, .hard, .again, .good, .good], at: 0, of: &deck)
        let progress = evaluate([deck])
        #expect(DeckActivity(deck: deck, calendar: calendar).reviewsByDay[today] == 6)
        #expect(progress.ring == DailyRing(done: 1, goal: 2))
    }

    @Test func cardsAddedAfterTheDayBeganAreNotInTheGoal() throws {
        var options = options()
        options.newCardsPerSession = 10
        var deck = try Deck(learningOptions: options, cards: (0..<4).map { due("c\($0)", onDay: today) } + (0..<3).map { new("n\($0)") })
        #expect(evaluate([deck]).ring == DailyRing(done: 0, goal: 7))
        // Five cards are added in the afternoon: they are new cards within the limit, so the plan owes them...
        deck.cards += (0..<5).map { Card(question: "late\($0)", answer: "x", created: now.addingTimeInterval(-60)) }
        #expect(StudySession.counts(for: deck, at: now, calendar: calendar).total == 12)
        // ...but the goal of the day was set when it began.
        #expect(evaluate([deck]).ring == DailyRing(done: 0, goal: 7))
        reviewPlan(of: &deck, at: now)
        // Everything is learned, the added cards too: the extra five are a lap, not debt.
        let ring = evaluate([deck]).ring
        #expect(ring == DailyRing(done: 12, goal: 7))
        #expect(ring.laps == 1)
        #expect(ring.isGoalMet)
    }

    @Test func extraNewCardsBeyondThePlanGoToLapsAndDoNotRaiseTheGoal() throws {
        var options = options()
        options.newCardsPerSession = 3
        var deck = try Deck(learningOptions: options, cards: (0..<4).map { due("c\($0)", onDay: today) } + (0..<10).map { new("n\($0)") })
        #expect(evaluate([deck]).ring == DailyRing(done: 0, goal: 7))
        reviewPlan(of: &deck, at: now)
        #expect(evaluate([deck]).ring == DailyRing(done: 7, goal: 7))
        #expect(StudySession.counts(for: deck, at: now, calendar: calendar).total == 0)
        // "+10 new", here five: the limit of the day is used up, the stream asks for them on top.
        var extra = StudySession(deck: deck, at: now, calendar: calendar, random: SeededRandom(seed: 1), reviewMode: .revealed, extraNew: 5)
        while let id = extra.session.currentCardID {
            deck.cards[deck.index(of: id)!] = extra.review(.good, of: deck.card(withID: id)!, with: deck.learningOptions, at: now, calendar: calendar)!
        }
        let ring = evaluate([deck]).ring
        #expect(ring == DailyRing(done: 12, goal: 7))
        #expect(ring.laps == 1)
        #expect(ring.fraction > 1.7)
    }

    @Test func cardsBeyondThePlanCountTowardTheLaps() throws {
        // A plan of 6, then 14 cards not due until tomorrow, reviewed all the same.
        var deck = try Deck(learningOptions: options(), cards: (0..<6).map { due("c\($0)", onDay: today) } + (0..<14).map { due("a\($0)", onDay: today + 1) })
        reviewPlan(of: &deck, at: now)
        var ahead = StudySession(cardIDs: deck.cards.suffix(14).map(\.id), at: now, random: SeededRandom(seed: 1), reviewMode: .revealed)
        for _ in 0..<14 {
            let id = ahead.session.currentCardID!
            deck.cards[deck.index(of: id)!] = ahead.review(.good, of: deck.card(withID: id)!, with: deck.learningOptions, at: now, calendar: calendar)!
        }
        let ring = evaluate([deck]).ring
        #expect(ring == DailyRing(done: 20, goal: 6))
        #expect(ring.laps == 3)
        #expect(ring.isGoalMet)
    }

    @Test func aPlanOfNothingIsAGoalOfNothingAndTheDayCounts() throws {
        // Learned `interval - 1` days ago, nothing due before tomorrow.
        let deck = try Deck(learningOptions: options(), cards: (0..<5).map { due("c\($0)", onDay: today + 1) })
        let progress = evaluate([deck])
        #expect(progress.ring == DailyRing(done: 0, goal: 0))
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
        #expect(progress.ring == DailyRing(done: 0, goal: 2))
        #expect(progress.streak == Streak(days: before, repairCards: 2))
        review(1, of: &deck, at: now)
        progress = evaluate([deck])
        #expect(progress.streak == Streak(days: before, repairCards: 1))
        // The plan of today done: yesterday counts, too.
        review(1, of: &deck, at: now)
        progress = evaluate([deck])
        #expect(progress.ring == DailyRing(done: 2, goal: 2))
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

    @Test func aPastDayIsJudgedByWhatWasDoneOnIt() throws {
        // Eight cards fell due the day before yesterday and nobody studied until today.
        var deck = try Deck(learningOptions: options(), cards: (0..<8).map { due("c\($0)", onDay: today - 2) })
        review(7, of: &deck, at: now, all: true)
        // Two missed days in a row, and the plan of today, which is a share of the cards left, is done.
        #expect(evaluate([deck]).streak == Streak(days: 1, repairCards: nil))
        // The last one done, a day late: the two days stay missed, as nothing was done on them.
        review(1, of: &deck, at: now, all: true)
        #expect(evaluate([deck]).streak == Streak(days: 1, repairCards: nil))
    }

    @Test func aPastDayWithAnswersAndAnUnfinishedPlanCountsBeforeThePlanRuleAndNotAfterIt() throws {
        // Eight cards were due yesterday, three of them were reviewed that day, five were left; nothing is new.
        var deck = try Deck(learningOptions: options(), cards: (0..<8).map { due("c\($0)", onDay: today - 1) })
        review(3, of: &deck, at: now.addingTimeInterval(-86400))
        // Before the cutover yesterday counts with its answers. Today's plan is open: a seventh of the five left over, one card.
        let legacy = evaluate([deck], planRuleStart: today)
        #expect(legacy.streak == Streak(days: interval + 1, repairCards: nil))
        // From the cutover on the same day is missed, and today can still repair it.
        let planned = evaluate([deck], planRuleStart: today - 1)
        #expect(planned.streak == Streak(days: interval, repairCards: 1))
        // The ring is the plan of today either way.
        #expect(legacy.ring == planned.ring)
        #expect(planned.ring == DailyRing(done: 0, goal: 1))
    }

    @Test func aCardThatDidNotExistYetWasNotInThePlanOfThatDay() throws {
        var options = options()
        options.newCardsPerSession = 5
        // Studied for a while, then ten new cards were added today.
        var cards = (0..<3).map { due("c\($0)", onDay: today + 1) }
        cards += (0..<10).map { Card(id: UUID(), question: "n\($0)", answer: "x", created: now.addingTimeInterval(-3600)) }
        let deck = try Deck(learningOptions: options, cards: cards)
        let activity = DeckActivity(deck: deck, calendar: calendar)
        let history = activity.history(from: today - 1, at: now, calendar: calendar)
        #expect(history.starts[today - 1] == .init(other: 0, new: 0))
        // Today began without them, so they are no part of its plan; the ceiling of the new cards a day
        // that began now would take counts them.
        #expect(history.starts[today] == .init(other: 0, new: 0))
        #expect(history.newCeilingToday == 5)
        #expect(activity.owed(now: now, calendar: calendar).total == 5)
        #expect(activity.owed(now: now, calendar: calendar, newCardAllowance: 2).total == 2)
    }

    @Test func aBacklogOfFifteenHundredIsAPlanOfTheOnTimeCardsAndTwoHundredFifteenWhoseGoalIsTwoRounds() throws {
        let onTime = (0..<12).map { due("t\($0)", onDay: today) }
        let backlog = (0..<1500).map { due("b\($0)", onDay: today - 1 - $0 % 5) }
        var deck = try Deck(learningOptions: options(), cards: onTime + backlog)
        let progress = evaluate([deck])
        // The plan is the on-time cards and the share of the backlog; the goal is the 48 reviews of four rounds.
        #expect(progress.capacity == 4)
        #expect(progress.ring == DailyRing(done: 0, goal: 48))
        #expect(progress.cardsLeft == 12 + 215)
        let counts = StudySession.counts(for: deck, at: now, calendar: calendar)
        #expect(counts.total == 12 + 215)
        #expect(counts.catchUp == 1500 - 215)
        // The most forgotten of the backlog come first, and all the on-time cards, which are less forgotten, come too.
        reviewPlan(of: &deck, at: now)
        #expect(evaluate([deck]).ring == DailyRing(done: 12 + 215, goal: 48))
        #expect(StudySession.counts(for: deck, at: now, calendar: calendar).total == 0)
        #expect(StudySession.counts(for: deck, at: now, calendar: calendar).catchUp == 1500 - 215)
    }

    @Test func aBacklogOfFifteenHundredWithTwelveOnTimeAndNewCardsLeavesNoTimeForTheNewOnes() throws {
        var options = options()
        options.newCardsPerSession = 7
        let onTime = (0..<12).map { due("t\($0)", onDay: today) }
        let backlog = (0..<1500).map { due("b\($0)", onDay: today - 1 - $0 % 5) }
        var deck = try Deck(learningOptions: options, cards: onTime + backlog + (0..<30).map { new("n\($0)") })
        // Twelve on time, a seventh of the backlog rounded up, and the new cards of the day.
        let plan = 12 + 215 + 7
        #expect(StudySession.counts(for: deck, at: now, calendar: calendar).total == plan)
        #expect(DeckActivity(deck: deck, calendar: calendar).plan(onDayOf: now, calendar: calendar).total == plan)
        // The reviews fill the four rounds of the day, so no new card is admitted and the goal is those 48.
        let progress = evaluate([deck])
        #expect(progress.newCardAllowances == [0])
        #expect(progress.ring == DailyRing(done: 0, goal: 48))
        reviewPlan(of: &deck, at: now)
        #expect(evaluate([deck]).ring == DailyRing(done: plan, goal: 48))
        // The rest of the backlog is catching up: laps, and the goal stays.
        review(100, of: &deck, at: now, all: true)
        #expect(evaluate([deck]).ring == DailyRing(done: plan + 100, goal: 48))
    }

    @Test func aSmallBacklogIsDoneInADayAsLongAsTheDaysOwnCardsAreMore() throws {
        // One missed day: five cards left over, thirty due today.
        var deck = try Deck(learningOptions: options(), cards: (0..<30).map { due("t\($0)", onDay: today) } + (0..<5).map { due("b\($0)", onDay: today - 1) })
        var counts = StudySession.counts(for: deck, at: now, calendar: calendar)
        #expect(counts.total == 35)
        #expect(counts.catchUp == 0)
        // Yesterday's five cards were missed, which takes a round from today: two rounds hold 24 reviews.
        #expect(evaluate([deck]).ring == DailyRing(done: 0, goal: 24))
        // Nothing of the plan is left over once it is done.
        reviewPlan(of: &deck, at: now)
        counts = StudySession.counts(for: deck, at: now, calendar: calendar)
        #expect(counts.total == 0)
        #expect(counts.catchUp == 0)
        #expect(evaluate([deck]).ring == DailyRing(done: 35, goal: 24))
    }

    @Test func theBacklogShareGoesBySeventhsWhileTheDaysOwnCardsAreFewerAndTheGoalIsTheRoundsOfTheDay() throws {
        // 1500 overdue and 50 due today: the share is 215, not the 50 of a normal day.
        let deck = try Deck(
            learningOptions: options(), cards: (0..<50).map { due("t\($0)", onDay: today) } + (0..<1500).map { due("b\($0)", onDay: today - 1 - $0 % 5) })
        #expect(StudySession.counts(for: deck, at: now, calendar: calendar).total == 50 + 215)
        #expect(evaluate([deck]).cardsLeft == 50 + 215)
        #expect(evaluate([deck]).ring == DailyRing(done: 0, goal: 48))
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
            #expect(evaluate([deck]).ring == DailyRing(done: done, goal: 24), "after \(done)")
            #expect(StudySession.counts(for: deck, at: now, calendar: calendar).total == 80 - done, "after \(done)")
        }
        #expect(evaluate([deck]).ring.isGoalMet)
    }

    @Test func sixHundredOverdueAndNothingDueAsksEightySixWhichTheGoalCutsToTwoRounds() throws {
        let deck = try Deck(learningOptions: options(), cards: (0..<600).map { due("b\($0)", onDay: today - 1 - $0 % 3) })
        #expect(StudySession.counts(for: deck, at: now, calendar: calendar).total == 86)
        #expect(evaluate([deck]).cardsLeft == 86)
        #expect(evaluate([deck]).ring == DailyRing(done: 0, goal: 24))
    }

    @Test func theSizeOfASessionCapsNeitherThePlanNorWhatIsShown() throws {
        // The default size of a session, 100, is the size of a segment of the stream, no cap on the plan.
        var options = options()
        options.cardsPerSession = LearningOptions().cardsPerSession
        #expect(options.cardsPerSession == 100)
        let onTime = (0..<12).map { due("t\($0)", onDay: today) }
        let backlog = (0..<1500).map { due("b\($0)", onDay: today - 1 - $0 % 5) }
        var deck = try Deck(learningOptions: options, cards: onTime + backlog)
        let plan = 12 + 215
        #expect(StudySession.counts(for: deck, at: now, calendar: calendar).total == plan)
        #expect(evaluate([deck]).ring == DailyRing(done: 0, goal: 48))
        // The stream takes the plan in segments of a hundred, and the goal doesn't grow with them.
        #expect(StudySession(deck: deck, at: now, calendar: calendar, random: SeededRandom(seed: 1)).session.totalCount == 100)
        var done = 0
        while StudySession.counts(for: deck, at: now, calendar: calendar).total > 0 {
            let segment = StudySession(deck: deck, at: now, calendar: calendar, random: SeededRandom(seed: 1)).session.totalCount
            review(segment, of: &deck, at: now)
            done += segment
            let ring = evaluate([deck]).ring
            #expect(ring == DailyRing(done: done, goal: 48))
            #expect(StudySession.counts(for: deck, at: now, calendar: calendar).total == plan - done)
        }
        #expect(done == plan)
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
            #expect(evaluate([deck], at: date).ring == DailyRing(done: 0, goal: share), "day \(day)")
            reviewPlan(of: &deck, at: date)
            #expect(evaluate([deck], at: date).ring == DailyRing(done: share, goal: share), "day \(day) done")
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
        #expect(evaluate([deck]).ring == DailyRing(done: 0, goal: 10))
        // Nine of the ten: one card short of the goal, the day is not met.
        review(9, of: &deck, at: now)
        var progress = evaluate([deck])
        #expect(progress.ring == DailyRing(done: 9, goal: 10))
        #expect(!progress.ring.isGoalMet)
        #expect(progress.streak.days == 0)
        // The tenth meets the goal and the day. The days since the cards were due are missed.
        review(1, of: &deck, at: now)
        progress = evaluate([deck])
        #expect(progress.ring == DailyRing(done: 10, goal: 10))
        #expect(progress.ring.isGoalMet)
        #expect(progress.streak == Streak(days: 1, repairCards: nil))
        // Catching up beyond the goal fills the laps and changes neither the goal nor the streak.
        review(20, of: &deck, at: now, all: true)
        progress = evaluate([deck])
        #expect(progress.ring == DailyRing(done: 30, goal: 10))
        #expect(progress.ring.laps == 3)
        #expect(progress.streak == Streak(days: 1, repairCards: nil))
    }

    @Test func aDayIsMetWhenItsRingIsClosedAndCardsAddedLaterDoNotUnmeetIt() throws {
        var options = options()
        options.newCardsPerSession = 10
        var deck = try Deck(learningOptions: options, cards: (0..<5).map { due("c\($0)", onDay: today) })
        #expect(evaluate([deck]).streak == Streak(days: interval, repairCards: nil))
        review(4, of: &deck, at: now)
        // Four of five: the ring is open, so the day is not met, whatever came before.
        var progress = evaluate([deck])
        #expect(progress.ring == DailyRing(done: 4, goal: 5))
        #expect(progress.streak.days == interval)
        review(1, of: &deck, at: now)
        progress = evaluate([deck])
        #expect(progress.ring.isGoalMet)
        #expect(progress.streak.days == interval + 1)
        // Six new cards are added: the plan owes them now, the ring and the streak are as they were.
        deck.cards += (0..<6).map { Card(question: "late\($0)", answer: "x", created: now.addingTimeInterval(-60)) }
        #expect(StudySession.counts(for: deck, at: now, calendar: calendar).total == 6)
        progress = evaluate([deck])
        #expect(progress.ring == DailyRing(done: 5, goal: 5))
        #expect(progress.streak.days == interval + 1)
    }

    @Test func decksAddUp() throws {
        var first = try Deck(learningOptions: options(), cards: (0..<30).map { due("a\($0)", onDay: today) })
        let second = try Deck(learningOptions: options(), cards: (0..<5).map { due("b\($0)", onDay: today) })
        // Together the plan is 35 cards, whichever deck the reviews are in.
        #expect(evaluate([first, second]).ring == DailyRing(done: 0, goal: 35))
        reviewPlan(of: &first, at: now)
        var progress = evaluate([first, second])
        #expect(progress.ring == DailyRing(done: 30, goal: 35))
        #expect(!progress.ring.isGoalMet)
        // One deck alone is a smaller picture.
        #expect(evaluate([second]).ring == DailyRing(done: 0, goal: 5))
        var rest = second
        reviewPlan(of: &rest, at: now)
        progress = evaluate([first, rest])
        #expect(progress.ring == DailyRing(done: 35, goal: 35))
    }

    @Test func aCardDoneAtThreeFiftyNineBelongsToTheStudyDayBefore() throws {
        // 2026-10-06 03:59:59 and 04:00:00 in Berlin.
        let before = calendar.start(ofDay: today + 1).addingTimeInterval(-1)
        let after = calendar.start(ofDay: today + 1)
        // A card that existed when the day began, learned with two Goods at 03:59.
        let log = [ReviewLogEntry(date: before.addingTimeInterval(-30), grade: .good, mode: .revealed), ReviewLogEntry(date: before, grade: .good, mode: .revealed)]
        let card = Scheduler(learningOptions: options(), calendar: calendar).replaying(log, of: new("q"))
        let deck = try Deck(learningOptions: options(), cards: [card])
        // Just before four the day is still 2026-10-05: the plan of its start was the new card, and it is done.
        let evening = evaluate([deck], at: before)
        #expect(evening.ring == DailyRing(done: 1, goal: 1))
        // A second later it is the next day: nothing was due then and nothing is done on it, yet
        // yesterday and today are both in the streak.
        let morning = evaluate([deck], at: after)
        #expect(morning.ring == DailyRing(done: 0, goal: 0))
        #expect(morning.ring.isGoalMet)
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
