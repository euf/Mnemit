import Foundation
import Testing

@testable import VocabCore

/// The time of a day, in seconds: the pure rule (`DailyGoal.nextTime(after:)`) over model learners, a day at a time,
/// as `DailyProgress.evaluate` steps through the days.
struct RingRuleTests {
    typealias Day = DailyGoal.RingDay

    /// `days` more days after `history`, with a learner who works `work(asked)` seconds on a day whose ring asks
    /// `asked` seconds, and none on the days of `rest`. A ring is closed when the work reaches the seconds it asked.
    func simulate(_ history: [Day] = [], days: Int, rest: Set<Int> = [], work: (Double) -> Double) -> [Day] {
        var all = history
        let start = (history.last?.day ?? -1) + 1
        for day in start..<(start + days) {
            let size = DailyGoal.nextTime(after: all)
            let worked = rest.contains(day) ? 0 : work(size.time)
            all.append(Day(day: day, time: size.time, reason: size.reason, worked: worked, closed: worked >= size.time, studied: worked > 0))
        }
        return all
    }

    @Test func theFirstDayAsksTheInitialTimeAndSoDoesAnyDayBeforeAnyWork() {
        #expect(DailyGoal.nextTime(after: []) == (DailyGoal.initialSeconds, .start))
        #expect(DailyGoal.nextTime(after: [Day(day: 0, worked: 0, closed: false, studied: false)]) == (DailyGoal.initialSeconds, .start))
    }

    @Test func oneStepHoldsTheTimeOnTheFirstClosedRingMultipliesItByGrowsOnTheSecondAndByShrinksWhenTheRingStayedOpen() {
        func next(asked: Double, worked: Double, closed: Bool) -> (time: Double, reason: DailyGoal.SizeReason) {
            DailyGoal.nextTime(after: [Day(day: 0, time: asked, worked: worked, closed: closed, studied: true)])
        }
        // One closed ring is the first of a run: the time stays, however much was worked beyond the ring.
        #expect(next(asked: 240, worked: 240, closed: true) == (240, .closedInARow))
        #expect(next(asked: 600, worked: 1_000_000, closed: true) == (600, .closedInARow))
        // The second closed ring in a row: 240 × 1.15 = 276 and 600 × 1.15 = 690.
        func nextAfterTwo(asked: Double, worked: Double) -> (time: Double, reason: DailyGoal.SizeReason) {
            DailyGoal.nextTime(after: [
                Day(day: 0, time: asked, worked: asked, closed: true, studied: true),
                Day(day: 1, time: asked, reason: .closedInARow, worked: worked, closed: true, studied: true),
            ])
        }
        #expect(abs(nextAfterTwo(asked: 240, worked: 240).time - 276) < 1e-9)
        #expect(abs(nextAfterTwo(asked: 600, worked: 600).time - 690) < 1e-9)
        #expect(abs(nextAfterTwo(asked: 600, worked: 1_000_000).time - 690) < 1e-9)
        #expect(nextAfterTwo(asked: 600, worked: 600).reason == .ringClosed)
        // Open: 240 × 0.775 = 186 and 600 × 0.775 = 465, however little or much was worked short of the ring.
        #expect(abs(next(asked: 240, worked: 100, closed: false).time - 186) < 1e-9)
        #expect(abs(next(asked: 600, worked: 1, closed: false).time - 465) < 1e-9)
        #expect(abs(next(asked: 600, worked: 599, closed: false).time - 465) < 1e-9)
        #expect(next(asked: 600, worked: 100, closed: false).reason == .ringOpen)
        // The last study day alone counts: an open day after a closed one gives 240 × 0.775 = 186.
        let closed = Day(day: 0, time: 240, worked: 240, closed: true, studied: true)
        let open = Day(day: 1, time: 240, reason: .closedInARow, worked: 100, closed: false, studied: true)
        #expect(abs(DailyGoal.nextTime(after: [closed, open]).time - 186) < 1e-9)
    }

    @Test func aLearnerWhoStopsAtTheRingGrowsFromTwoAndAHalfMinutesByFifteenPercentEveryTwoClosedDays() {
        let days = simulate(days: 12) { $0 }
        #expect(days.allSatisfy { $0.closed })
        // Day 1 asks the 150 s of the start and day 2 the same, after the first closed ring; day 3, 150 × 1.15 = 172.5 s,
        // after the second; day 10, 150 × 1.15^4 = 262.351 s.
        #expect(days[0].time == 150 && days[0].reason == .start)
        #expect(days[1].time == 150 && days[1].reason == .closedInARow)
        #expect(abs(days[2].time - 172.5) < 1e-9 && days[2].reason == .ringClosed)
        #expect(abs(days[9].time - 262.350_937_5) < 1e-9)
        for (index, day) in days.enumerated() {
            #expect(abs(day.time - 150 * pow(1.15, Double(index / 2))) < 1e-9)
            // The first closed ring of a pair holds the time, the second grows it.
            #expect(day.reason == (index == 0 ? .start : index % 2 == 1 ? .closedInARow : .ringClosed))
        }
    }

    @Test func theFirstClosedRingOfARunHoldsTheTimeTheSecondGrowsItAndAnOpenRingBreaksTheRun() {
        // Closed, closed, open, closed, closed, closed: the run counts closed rings since the last open one or growth.
        var days = simulate(days: 2) { $0 }
        days = simulate(days, days: 1) { $0 / 2 }
        days = simulate(days, days: 3) { $0 }
        // Day 1 150 s (start); day 2 150 s, the first closed ring holds it; day 3 150 × 1.15 = 172.5 s, the second;
        // day 4 172.5 × 0.775 = 133.6875 s, the third ring was open; day 5 the same, the first closed ring of a new run;
        // day 6 133.6875 × 1.15 = 153.740625 s, the second.
        #expect(days.map(\.reason) == [.start, .closedInARow, .ringClosed, .ringOpen, .closedInARow, .ringClosed])
        #expect(days.map(\.closed) == [true, true, false, true, true, true])
        for (day, time) in zip(days, [150, 150, 172.5, 133.6875, 133.6875, 153.740_625]) {
            #expect(abs(day.time - time) < 1e-9)
        }
        // The day after the third closed ring in a row holds the time again: 153.740625 s.
        let third = DailyGoal.nextTime(after: days)
        #expect(third.reason == .closedInARow && abs(third.time - 153.740_625) < 1e-9)
    }

    @Test func aLearnerWhoWorksLessThanTheRingAsksIsAskedLessAndLessDownToTwoMinutes() {
        let days = simulate(days: 6) { _ in 60 }
        // 150, then 150 × 0.775 = 116.25 would be under two minutes, so 120 s from the second day.
        #expect(abs(days[0].time - 150) < 1e-9)
        #expect(days[1...].allSatisfy { $0.time == 120 })
        #expect(days.dropFirst().allSatisfy { $0.reason == .ringOpen })
        #expect(days.allSatisfy { !$0.closed })
    }

    @Test func aMissedDayChangesNothing() {
        let history = [Day(day: 0, time: 240, worked: 240, closed: true, studied: true), Day(day: 1, time: 240, reason: .closedInARow, worked: 100, closed: false, studied: true)]
        // A day with nothing done after them asks what they asked: 240 × 0.775 = 186.
        #expect(DailyGoal.nextTime(after: history + [Day(day: 2, time: 186, worked: 0, closed: false, studied: false)]) == DailyGoal.nextTime(after: history))
        #expect(abs(DailyGoal.nextTime(after: history).time - 186) < 1e-9)
        // An empty plan closes its ring with nothing done (done >= goal at 0): still no step.
        #expect(DailyGoal.nextTime(after: history + [Day(day: 2, time: 186, worked: 0, closed: true, studied: false)]) == DailyGoal.nextTime(after: history))
        // Over a month a rest day is no step: the day after it asks what it asked, and the run goes on as if it had not been.
        let plain = simulate(days: 28) { $0 }
        let rested = simulate(days: 28, rest: [10]) { $0 }
        #expect(rested[10].worked == 0 && rested[11].time == rested[10].time)
        #expect(rested[0...10].map(\.time) == plain[0...10].map(\.time))
        #expect(rested[11...].map(\.time) == plain[10..<27].map(\.time))
    }

    @Test func aRingClosedOnAPlanSmallerThanItsTimeKeepsTheTime() {
        // A deck's new-card limit set the goal below the time: the closed ring asked less than the time, so it says
        // nothing of more, and the next day asks the same; closed rings on full plans count toward growth.
        let small = Day(day: 0, time: 600, worked: 300, closed: true, studied: true, filled: false)
        #expect(DailyGoal.nextTime(after: [small]) == (600, .smallPlan))
        let full = Day(day: 0, time: 600, worked: 600, closed: true, studied: true, filled: true)
        #expect(DailyGoal.nextTime(after: [full]) == (600, .closedInARow))
        #expect(abs(DailyGoal.nextTime(after: [full, full]).time - 600 * DailyGoal.grows) < 1e-9)
        // An open ring shrinks whatever set its goal.
        let open = Day(day: 0, time: 600, worked: 100, closed: false, studied: true, filled: false)
        #expect(DailyGoal.nextTime(after: [open]).reason == .ringOpen)
    }

    @Test func aRingClosedOnASmallPlanNeitherCountsInARunNorBreaksIt() {
        let full = Day(day: 0, time: 600, worked: 600, closed: true, studied: true, filled: true)
        let small = Day(day: 1, time: 600, reason: .closedInARow, worked: 300, closed: true, studied: true, filled: false)
        // Two full rings with a small one between them are two in a row: 600 × 1.15 = 690.
        let between = DailyGoal.nextTime(after: [full, small, Day(day: 2, time: 600, reason: .smallPlan, worked: 600, closed: true, studied: true)])
        #expect(between.reason == .ringClosed && abs(between.time - 690) < 1e-9)
        // A small ring after a full one is no second ring: the time stays, as the small plan holds it.
        #expect(DailyGoal.nextTime(after: [full, small]) == (600, .smallPlan))
        // A small ring before the first full one is no first ring: one full ring after it holds the time.
        let afterSmall = Day(day: 1, time: 600, reason: .smallPlan, worked: 600, closed: true, studied: true)
        #expect(DailyGoal.nextTime(after: [Day(day: 0, time: 600, worked: 300, closed: true, studied: true, filled: false), afterSmall]) == (600, .closedInARow))
        // An open ring before them breaks the run all the same: open, small, full is one closed ring.
        let open = Day(day: 0, time: 600, worked: 100, closed: false, studied: true)
        let reopened = Day(day: 1, time: 465, reason: .ringOpen, worked: 100, closed: true, studied: true, filled: false)
        let last = Day(day: 2, time: 465, reason: .smallPlan, worked: 465, closed: true, studied: true)
        #expect(DailyGoal.nextTime(after: [open, reopened, last]) == (465, .closedInARow))
    }

    @Test func theGoalFillsTheTimeOnlyWhenTheTimeCutThePlan() {
        let pace = Pace(newCard: 30, otherCard: 10)
        // 600 s: 20 reviews take 200 s, 13 new cards 390 s, 10 s are left, under a new card: the time set the goal.
        #expect(DayRounds(otherCards: 20, newCards: 13, pace: pace, seconds: 600).filled)
        // Five new cards are all the deck allows: 350 s of 600, the plan set the goal.
        #expect(!DayRounds(otherCards: 20, newCards: 5, pace: pace, seconds: 600).filled)
        // Reviews alone over the time are cut by it.
        #expect(DayRounds(otherCards: 100, newCards: 0, pace: pace, seconds: 600).filled)
        // Cut inside the reviews the next card is a review, whatever a new card costs: 19 reviews of 10 s leave 3.5 s of
        // 193.5, under the review but over a new card of 2 s.
        #expect(DayRounds(otherCards: 100, newCards: 0, pace: Pace(newCard: 2, otherCard: 10), seconds: 193.5).filled)
        // No plan, no goal.
        #expect(!DayRounds(otherCards: 0, newCards: 0, pace: pace, seconds: 600).filled)
    }

    @Test func theTimeStaysBetweenTwoMinutesAndAnHour() {
        // Ring open every day: 150, then 116.25 is under two minutes, so 120 s from the second day on.
        let tiny = simulate(days: 20) { _ in 10 }
        #expect(tiny[0].time > 120 && tiny[1...].allSatisfy { $0.time == 120 })
        #expect(DailyGoal.nextTime(after: [Day(day: 0, time: 120, worked: 10, closed: false, studied: true)]).time == 120)
        // Ring closed every day: 150 × 1.15^22 = 3246.7 on the 45th and 46th days, whose step, 3733.7, is cut to 3600 s on the 47th.
        let huge = simulate(days: 60) { _ in 10_000 }
        #expect(huge[45].time < 3600 && huge[46...].allSatisfy { $0.time == 3600 })
        let top = Day(day: 0, time: 3600, worked: 10_000, closed: true, studied: true)
        #expect(DailyGoal.nextTime(after: [top, top]).time == 3600)
        // From the floor two closed days grow it again: 120 × 1.15 = 138.
        let floor = Day(day: 0, time: 120, worked: 120, closed: true, studied: true)
        #expect(abs(DailyGoal.nextTime(after: [floor, floor]).time - 138) < 1e-9)
    }
}
