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

    @Test func oneStepMultipliesTheTimeByGrowsWhenTheRingClosedAndByShrinksWhenItStayedOpen() {
        func next(asked: Double, worked: Double, closed: Bool) -> (time: Double, reason: DailyGoal.SizeReason) {
            DailyGoal.nextTime(after: [Day(day: 0, time: asked, worked: worked, closed: closed, studied: true)])
        }
        // Closed: 240 × 1.075 = 258 and 600 × 1.075 = 645, however much was worked beyond the ring.
        #expect(abs(next(asked: 240, worked: 240, closed: true).time - 258) < 1e-9)
        #expect(abs(next(asked: 600, worked: 600, closed: true).time - 645) < 1e-9)
        #expect(abs(next(asked: 600, worked: 1_000_000, closed: true).time - 645) < 1e-9)
        #expect(next(asked: 600, worked: 600, closed: true).reason == .ringClosed)
        // Open: 240 × 0.775 = 186 and 600 × 0.775 = 465, however little or much was worked short of the ring.
        #expect(abs(next(asked: 240, worked: 100, closed: false).time - 186) < 1e-9)
        #expect(abs(next(asked: 600, worked: 1, closed: false).time - 465) < 1e-9)
        #expect(abs(next(asked: 600, worked: 599, closed: false).time - 465) < 1e-9)
        #expect(next(asked: 600, worked: 100, closed: false).reason == .ringOpen)
        // The last study day alone counts: an open day after a closed one gives 240 × 1.075 × 0.775 = 199.95.
        let closed = Day(day: 0, time: 240, worked: 240, closed: true, studied: true)
        let open = Day(day: 1, time: 258, worked: 100, closed: false, studied: true)
        #expect(abs(DailyGoal.nextTime(after: [closed, open]).time - 199.95) < 1e-9)
    }

    @Test func aLearnerWhoStopsAtTheRingGrowsFromFourMinutesBySevenAndAHalfPercentAClosedDay() {
        let days = simulate(days: 12) { $0 }
        #expect(days.allSatisfy { $0.closed })
        // Day 1 asks the 240 s of the start; day 2, 240 × 1.075 = 258 s; day 10, 240 × 1.075^9 = 460.137 s.
        #expect(days[0].time == 240 && days[0].reason == .start)
        #expect(abs(days[1].time - 258) < 1e-9)
        #expect(abs(days[9].time - 460.137_278_994_912_2) < 1e-9)
        for (index, day) in days.enumerated() {
            #expect(abs(day.time - 240 * pow(1.075, Double(index))) < 1e-9)
            #expect(day.reason == (index == 0 ? .start : .ringClosed))
        }
    }

    @Test func aLearnerWhoWorksLessThanTheRingAsksIsAskedLessAndLessDownToTwoMinutes() {
        let days = simulate(days: 6) { _ in 60 }
        // 240, 240 × 0.775 = 186, 186 × 0.775 = 144.15, then 111.7 would be under two minutes, so 120 s from the fourth day.
        for (day, asked) in zip(days, [240, 186, 144.15]) { #expect(abs(day.time - asked) < 1e-9) }
        #expect(days[3...].allSatisfy { $0.time == 120 })
        #expect(days.dropFirst().allSatisfy { $0.reason == .ringOpen })
        #expect(days.allSatisfy { !$0.closed })
    }

    @Test func aMissedDayChangesNothing() {
        let history = [Day(day: 0, time: 240, worked: 240, closed: true, studied: true), Day(day: 1, time: 258, worked: 100, closed: false, studied: true)]
        // A day with nothing done after them asks what they asked: 258 × 0.775 = 199.95.
        #expect(DailyGoal.nextTime(after: history + [Day(day: 2, time: 199.95, worked: 0, closed: false, studied: false)]) == DailyGoal.nextTime(after: history))
        #expect(abs(DailyGoal.nextTime(after: history).time - 199.95) < 1e-9)
        // An empty plan closes its ring with nothing done (done >= goal at 0): still no step.
        #expect(DailyGoal.nextTime(after: history + [Day(day: 2, time: 199.95, worked: 0, closed: true, studied: false)]) == DailyGoal.nextTime(after: history))
        // Over a month a rest day is no step: the day after it asks what it asked, and the run goes on as if it had not been.
        let plain = simulate(days: 28) { $0 }
        let rested = simulate(days: 28, rest: [10]) { $0 }
        #expect(rested[10].worked == 0 && rested[11].time == rested[10].time)
        #expect(rested[0...10].map(\.time) == plain[0...10].map(\.time))
        #expect(rested[11...].map(\.time) == plain[10..<27].map(\.time))
    }

    @Test func theTimeStaysBetweenTwoAndThirtyMinutes() {
        // Ring open every day: 240, 186, 144.15, then 111.7 is under two minutes, so 120 s from the fourth day on.
        let tiny = simulate(days: 20) { _ in 10 }
        #expect(tiny[2].time > 120 && tiny[3...].allSatisfy { $0.time == 120 })
        #expect(DailyGoal.nextTime(after: [Day(day: 0, time: 120, worked: 10, closed: false, studied: true)]).time == 120)
        // Ring closed every day: 240 × 1.075^27 = 1691.4 on the 28th day, whose step, 1818.2, is cut to 1800 s on the 29th.
        let huge = simulate(days: 40) { _ in 10_000 }
        #expect(huge[27].time < 1800 && huge[28...].allSatisfy { $0.time == 1800 })
        #expect(DailyGoal.nextTime(after: [Day(day: 0, time: 1800, worked: 10_000, closed: true, studied: true)]).time == 1800)
        // From the floor a closed day grows again: 120 × 1.075 = 129.
        #expect(abs(DailyGoal.nextTime(after: [Day(day: 0, time: 120, worked: 120, closed: true, studied: true)]).time - 129) < 1e-9)
    }
}
