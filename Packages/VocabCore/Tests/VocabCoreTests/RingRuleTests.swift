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

    /// `count` study days of ten minutes each, rings closed.
    func tenMinuteDays(_ count: Int) -> [Day] {
        (0..<count).map { Day(day: $0, time: 600, worked: 600, closed: true, studied: true) }
    }

    @Test func theFirstDayAsksTheInitialTimeAndSoDoesAnyDayBeforeAnyWork() {
        #expect(DailyGoal.nextTime(after: []) == (DailyGoal.initialSeconds, .start))
        #expect(DailyGoal.nextTime(after: [Day(day: 0, worked: 0, closed: false, studied: false)]) == (DailyGoal.initialSeconds, .start))
    }

    @Test func oneStepMovesTheTimeTowardTheWorkWithTheRisingOrTheFallingWeightAndTheCap() {
        func next(asked: Double, worked: Double) -> Double {
            let size = DailyGoal.nextTime(after: [Day(day: 0, time: asked, worked: worked, closed: false, studied: true)])
            #expect(size.reason == .recentWork)
            return size.time
        }
        // The first day: 240 s asked, 600 worked; a day counts for at most 2 × 240 = 480, so 240 + 0.3 × (480 - 240) = 312.
        #expect(abs(next(asked: 240, worked: 600) - 312) < 1e-9)
        // Longer work, under the cap: 600 + 0.3 × (800 - 600) = 660.
        #expect(abs(next(asked: 600, worked: 800) - 660) < 1e-9)
        // Shorter work, the falling weight: 600 + 0.2 × (180 - 600) = 516.
        #expect(abs(next(asked: 600, worked: 180) - 516) < 1e-9)
        // Work equal to the ask changes nothing.
        #expect(abs(next(asked: 600, worked: 600) - 600) < 1e-9)
        // Work over twice the ask counts as twice: 600 + 0.3 × (1200 - 600) = 780, 1.3 times the ask is the most a day raises it.
        #expect(abs(next(asked: 600, worked: 1500) - 780) < 1e-9)
        #expect(abs(next(asked: 600, worked: 1_000_000) - 780) < 1e-9)
    }

    @Test func aLearnerWhoWorksTenMinutesADayFromTheFirstDayIsAskedNearlyTenByTheTenthAndNeverMore() {
        let days = simulate(days: 12) { _ in 600 }
        // The asks: 240, 312 (240 counts at most twice, 480: 240 + 0.3 × 240), 398.4, 458.9, 501.2, 530.9, 551.6, 566.1,
        // 576.3, 583.4: the tenth is 583 s, over 9.5 minutes (570 s), and every one stays under the 600 worked.
        #expect(days[9].time >= 570)
        #expect(days.allSatisfy { $0.time <= 600 })
        #expect(days.map(\.time) == days.map(\.time).sorted())
    }

    @Test func oneThreeMinuteDayInATenMinuteRunLowersTheNextToAboutEightAndAHalfAndTenMinutesAreBackWithinFiveDays() {
        let short = Day(day: 7, time: 600, worked: 180, closed: false, studied: true)
        let days = simulate(tenMinuteDays(7) + [short], days: 6) { _ in 600 }
        // The next day: 600 + 0.2 × (180 - 600) = 516 s, 8.6 minutes.
        #expect(abs(days[8].time - 516) < 1e-9)
        // Then 10 minutes worked on a day that asked 516: 541.2, 558.84, 571.19 (0.3 of what is missing each day).
        #expect(days[10].time < 570 && days[11].time >= 570)
        // The short day was the eighth; the fourth day after it asks over 9.5 minutes again.
        #expect(days[11].day - short.day <= 5)
    }

    @Test func oneTwentyFiveMinuteDayInATenMinuteRunRaisesTheNextToThirteenMinutesAtMostAndItDecays() {
        let long = Day(day: 7, time: 600, worked: 1500, closed: true, studied: true)
        let days = simulate(tenMinuteDays(7) + [long], days: 12) { _ in 600 }
        // 1500 counts as twice the ask, 1200: 600 + 0.3 × 600 = 780 s, 13 minutes, not a minute more.
        #expect(abs(days[8].time - 780) < 1e-9)
        // Back at ten minutes the excess falls by a fifth a day: 600 + 180 × 0.8^k.
        for offset in 0..<12 {
            #expect(abs(days[8 + offset].time - (600 + 180 * pow(0.8, Double(offset)))) < 1e-9)
        }
        #expect(days.last!.time < 620)
    }

    @Test func aSteadyLearnerWhoWorksExactlyTheRingKeepsItConstant() {
        // From the first day: four minutes asked, four worked, for a month.
        let fresh = simulate(days: 28) { $0 }
        #expect(fresh.allSatisfy { $0.time == DailyGoal.initialSeconds && $0.closed })
        // From ten minutes: the same.
        let tenMinutes = simulate(tenMinuteDays(7), days: 28) { $0 }.dropFirst(7)
        #expect(tenMinutes.allSatisfy { $0.time == 600 && $0.closed })
    }

    @Test func anEagerLearnerIsAskedNearlyWhatTheyWorkAndNeverMore() {
        let days = simulate(days: 14) { _ in 1200 }
        // The asks: 240, 312, 405.6, 527.3, 685.5 (the cap, twice the ask, binds until here), then 839.8, 947.9, 1023.5,
        // 1076.5, 1113.5: the tenth is 18.6 minutes. Each ask is under the 1200 worked, so every ring is closed.
        #expect(days[9].time >= 1080)
        #expect(days.allSatisfy { $0.time < 1200 && $0.closed })
        #expect(days.map(\.time) == days.map(\.time).sorted())
    }

    @Test func aMissedDayChangesNothing() {
        let history = [Day(day: 0, time: 240, worked: 600, closed: true, studied: true), Day(day: 1, time: 312, worked: 1000, closed: false, studied: true)]
        // A day with nothing done after them asks what they asked: 312 + 0.3 × (624 - 312) = 405.6.
        #expect(DailyGoal.nextTime(after: history + [Day(day: 2, time: 405.6, worked: 0, closed: false, studied: false)]) == DailyGoal.nextTime(after: history))
        #expect(abs(DailyGoal.nextTime(after: history).time - 405.6) < 1e-9)
        // Over a month a rest day is no step: the day after it asks what it asked, and the run goes on as if it had not been.
        let plain = simulate(days: 28) { _ in 600 }
        let rested = simulate(days: 28, rest: [10]) { _ in 600 }
        #expect(rested[10].worked == 0 && rested[11].time == rested[10].time)
        #expect(rested[0...10].map(\.time) == plain[0...10].map(\.time))
        #expect(rested[11...].map(\.time) == plain[10..<27].map(\.time))
    }

    @Test func theTimeStaysBetweenTwoAndThirtyMinutes() {
        // Ten seconds of work a day: 240, 194, 157.2, 127.8, then 104.2 would be under two minutes, so 120 s from the fifth day.
        let tiny = simulate(days: 20) { _ in 10 }
        #expect(tiny[3].time > 120 && tiny[4...].allSatisfy { $0.time == 120 })
        #expect(DailyGoal.nextTime(after: [Day(day: 0, time: 120, worked: 10, closed: false, studied: true)]).time == 120)
        // Ten thousand: 240 grows by 1.3 a day (the cap binds) to 1506 on the eighth day, whose step, 1957.8, is cut to 1800 s.
        let huge = simulate(days: 20) { _ in 10_000 }
        #expect(huge[7].time < 1800 && huge[8...].allSatisfy { $0.time == 1800 })
        #expect(DailyGoal.nextTime(after: [Day(day: 0, time: 1800, worked: 10_000, closed: true, studied: true)]).time == 1800)
    }
}
