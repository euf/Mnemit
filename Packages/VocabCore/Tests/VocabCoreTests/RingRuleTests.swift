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

    @Test func theBaseIsTheMedianOfTheLastSevenStudyDaysAndAnEvenCountTakesTheMiddlePair() {
        let worked: [Double] = [100, 100, 100, 100, 100, 100, 100, 600, 600, 700, 1000, 1000, 1000, 1000]
        let days = worked.enumerated().map { Day(day: $0.offset, worked: $0.element, closed: false, studied: true) }
        // The last seven are 600 600 700 1000 1000 1000 1000.
        #expect(DailyGoal.nextTime(after: days) == (1000, .median))
        // Two days: 600 and 1000.
        #expect(DailyGoal.nextTime(after: [days[7], Day(day: 13, worked: 1000, closed: false, studied: true)]) == (800, .median))
        // A day between that had no work is no part of it.
        let gap = [Day(day: 0, worked: 600, closed: false, studied: true), Day(day: 1, worked: 0, closed: true, studied: false), Day(day: 2, worked: 1000, closed: false, studied: true)]
        #expect(DailyGoal.nextTime(after: gap) == (800, .median))
    }

    @Test func aSteadyLearnerWhoWorksExactlyTheRingKeepsItConstant() {
        // From the first day: four minutes asked, four worked, for a month.
        let fresh = simulate(days: 28) { $0 }
        #expect(fresh.allSatisfy { $0.time == DailyGoal.initialSeconds && $0.closed })
        // From ten minutes: the same.
        let tenMinutes = simulate(tenMinuteDays(7), days: 28) { $0 }.dropFirst(7)
        #expect(tenMinutes.allSatisfy { $0.time == 600 && $0.closed })
    }

    @Test func anEagerLearnerIsAskedTwentyMinutesWithinEightDays() throws {
        let days = simulate(days: 8) { _ in 1200 }
        let reached = try #require(days.first { $0.time >= 1200 })
        #expect(reached.day < 8)
        // From the second day it asks what the first one worked, and the ring stays closed.
        #expect(days.dropFirst().allSatisfy { $0.time == 1200 && $0.closed })
    }

    @Test func aMissedDayChangesNothing() {
        let history = [Day(day: 0, worked: 600, closed: true, studied: true), Day(day: 1, worked: 1000, closed: false, studied: true)]
        // A day with nothing done after them asks what they asked: the median of 600 and 1000.
        #expect(DailyGoal.nextTime(after: history + [Day(day: 2, worked: 0, closed: false, studied: false)]) == DailyGoal.nextTime(after: history))
        #expect(DailyGoal.nextTime(after: history) == (800, .median))
        // Over a month the day after a rest day asks what the rest day asked.
        let rested = simulate(days: 28, rest: [10]) { min($0, 600) }
        #expect(rested[10].worked == 0 && rested[11].time == rested[10].time)
    }

    @Test func theTimeStaysBetweenTwoAndThirtyMinutes() {
        // Whatever the learner did: ten seconds of work leave two minutes, ten thousand thirty.
        let tiny = (0..<7).map { Day(day: $0, worked: 10, closed: true, studied: true) }
        #expect(DailyGoal.nextTime(after: tiny).time == 120)
        let huge = (0..<7).map { Day(day: $0, worked: 10_000, closed: true, studied: true) }
        #expect(DailyGoal.nextTime(after: huge).time == 1800)
    }
}
