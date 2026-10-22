import Foundation
import Testing

@testable import VocabCore

/// The size of a day under `DailyGoal.RingRule.follows`: the pure step (`DailyGoal.nextTime(for:after:)`) over
/// model learners, a day at a time, as `DailyProgress.evaluate` steps through the days.
struct RingRuleTests {
    typealias Day = DailyGoal.RingDay

    /// `days` more days after `history`, with a learner who works `work(asked)` seconds on a day whose ring asks
    /// `asked` seconds, and none on the days of `rest`, which are missed. A ring is closed when the work reaches the
    /// seconds of its rounds.
    func simulate(_ history: [Day] = [], days: Int, rest: Set<Int> = [], rule: DailyGoal.RingRule = .follows, work: (Double) -> Double) -> [Day] {
        var all = history
        let start = (history.last?.day ?? -1) + 1
        for day in start..<(start + days) {
            let size = DailyGoal.size(on: day, after: all, rule: rule)
            let asked = Double(size.capacity) * DailyGoal.roundSeconds
            let worked = rest.contains(day) ? 0 : work(asked)
            all.append(Day(day: day, capacity: size.capacity, reason: size.reason, worked: worked, closed: worked >= asked, studied: worked > 0, missed: rest.contains(day)))
        }
        return all
    }

    /// `count` study days of ten minutes each at five rounds, rings closed.
    func tenMinuteDays(_ count: Int) -> [Day] {
        (0..<count).map { Day(day: $0, capacity: 5, reason: .median, worked: 600, closed: true, studied: true) }
    }

    @Test func theFirstDayHoldsTheInitialRoundsAndAMissedFirstDaySoftensTheSecond() {
        let first = DailyGoal.nextTime(for: 0, after: [])
        #expect(first.time == Double(DailyGoal.initialCapacity) * DailyGoal.roundSeconds && first.reason == .start)
        let missed = DailyGoal.nextTime(for: 1, after: [Day(day: 0, worked: 0, closed: false, studied: false, missed: true)])
        #expect(missed.time == 168 && missed.reason == .afterMiss)
        #expect(DailyGoal.rounds(ofTime: missed.time) == 1)
    }

    @Test func theBaseIsTheMedianOfTheLastSevenStudyDaysAndAnEvenCountTakesTheMiddlePair() {
        let worked: [Double] = [100, 100, 100, 100, 100, 100, 100, 600, 600, 700, 1000, 1000, 1000, 1000]
        // Open rings, so that no probe is made: only the base is told.
        let days = worked.enumerated().map { Day(day: $0.offset, worked: $0.element, closed: false, studied: true) }
        // The last seven are 600 600 700 1000 1000 1000 1000.
        #expect(DailyGoal.nextTime(for: 14, after: days) == (1000, .median))
        // Two days: 600 and 1000.
        #expect(DailyGoal.nextTime(for: 14, after: [days[7], Day(day: 13, worked: 1000, closed: false, studied: true)]) == (800, .median))
        // A day between that was not studied is no part of it.
        let gap = [Day(day: 0, worked: 600, closed: false, studied: true), Day(day: 1, worked: 0, closed: true, studied: false), Day(day: 2, worked: 1000, closed: false, studied: true)]
        #expect(DailyGoal.nextTime(for: 3, after: gap) == (800, .median))
    }

    @Test func aSteadyLearnerLeavesTheRingOpenOnAtMostTwoDaysOfTwentyEight() {
        // Works the ring when it is under ten minutes, and ten minutes when it is more.
        let days = simulate(days: 28) { min($0, 600) }
        #expect(days.filter { !$0.closed }.count <= 2)
        #expect(days.allSatisfy { $0.capacity <= 6 })
    }

    @Test func theRoundsRuleLeavesTheRingOpenOnEightOfTwentyEightDaysForTheSameSteadyLearner() {
        let days = simulate(days: 28, rule: .rounds) { min($0, 600) }
        // Ten minutes, then twelve, then ten again: a sawtooth.
        #expect(days.filter { !$0.closed }.count == 8)
        #expect(Set(days.map(\.capacity)) == [2, 3, 4, 5, 6])
    }

    @Test func belowFiveRoundsAProbeRoundsAwayAndALearnerWhoWorksTheRingIsNotAskedMore() {
        for rounds in 1...4 { #expect(DailyGoal.rounds(ofTime: Double(rounds) * DailyGoal.roundSeconds * DailyGoal.probeFactor) == rounds) }
        #expect(DailyGoal.rounds(ofTime: 5 * DailyGoal.roundSeconds * DailyGoal.probeFactor) == 6)
        // Works exactly the ring from the first day's two rounds: the size stays where it began.
        let days = simulate(days: 28) { min($0, 600) }
        #expect(days.allSatisfy { $0.capacity == DailyGoal.initialCapacity && $0.closed })
    }

    @Test func aLearnerWhoStudiesTenMinutesWhateverTheRingAsksIsAskedTenMinutesFromTheSecondDay() {
        let days = simulate(days: 28) { _ in 600 }
        #expect(days[0].capacity == DailyGoal.initialCapacity && days[1].capacity == 5)
        // Each probe, at 12 minutes, is a day left open, and the next comes after three closed rings and a week.
        #expect(days.filter { !$0.closed }.map(\.day) == [3, 11, 19, 27])
        #expect(days.dropFirst().filter { !$0.probe }.allSatisfy { $0.capacity == 5 })
    }

    @Test func aLearnerAtTenMinutesIsAskedMoreOnlyEveryEighthDay() {
        // Seven days of ten minutes, then 28 more: each probe, at 12 minutes, fails; three closed rings and the
        // seven days of rest come before the next.
        let days = simulate(tenMinuteDays(7), days: 28) { min($0, 600) }.dropFirst(7)
        #expect(days.filter { !$0.closed }.count == 4)
        #expect(days.filter(\.probe).map(\.day) == [7, 15, 23, 31])
    }

    @Test func anEagerLearnerIsAskedTwentyMinutesWithinTenDays() throws {
        let days = simulate(days: 10) { _ in 1200 }
        let reached = try #require(days.first { Double($0.capacity) * DailyGoal.roundSeconds >= 1200 })
        #expect(reached.day < 10)
    }

    @Test func aMissedDaySoftensTheNextToSeventyPercentAndThatDayStaysOutOfTheBase() {
        // Two study days, 600 s and 1000 s, a missed day, then a softened one that worked little and left its ring open.
        let history = [
            Day(day: 0, worked: 600, closed: true, studied: true),
            Day(day: 1, worked: 1000, closed: false, studied: true),
            Day(day: 2, worked: 0, closed: false, studied: false, missed: true),
        ]
        let softened = DailyGoal.nextTime(for: 3, after: history)
        #expect(softened.time == 800 * 0.7 && softened.reason == .afterMiss)
        // The softened day: 100 s. Without it the base is still 800, the median of 600 and 1000, which with it would be 600.
        let after = history + [Day(day: 3, reason: .afterMiss, worked: 100, closed: false, studied: true)]
        #expect(DailyGoal.nextTime(for: 4, after: after) == (800, .median))
        // No probe on the softened day, even with three closed rings before it.
        let closedDays = tenMinuteDays(3) + [Day(day: 3, worked: 0, closed: false, studied: false, missed: true)]
        #expect(DailyGoal.nextTime(for: 4, after: closedDays) == (420, .afterMiss))
    }

    @Test func aFailedProbeStopsProbingForSevenDays() {
        let days = simulate(tenMinuteDays(7), days: 16) { min($0, 600) }
        let probes = days.filter(\.probe)
        // The first probe, at 12 minutes, fails: its ring stays open on 600 s.
        #expect(probes.first?.day == 7 && probes.first?.closed == false)
        #expect(probes.first?.capacity == 6)
        // The seven days after it ask no more than the base, though the rings are closed from the fourth day on.
        #expect(days.filter { (8...14).contains($0.day) }.allSatisfy { !$0.probe && $0.capacity == 5 })
        // Then the next probe.
        #expect(probes.map(\.day) == [7, 15])
    }

    @Test func threeClosedRingsInARowAreWhatAProbeWaitsFor() {
        let steady = tenMinuteDays(3)
        #expect(DailyGoal.nextTime(for: 3, after: steady) == (660, .probe))
        // One of the three open: no probe.
        var open = steady
        open[1].closed = false
        #expect(DailyGoal.nextTime(for: 3, after: open) == (600, .median))
        // Only two study days: no probe either.
        #expect(DailyGoal.nextTime(for: 2, after: Array(steady.prefix(2))) == (600, .median))
    }

    @Test func theTimeIsWholeRoundsBetweenOneAndFifteen() {
        #expect(DailyGoal.rounds(ofTime: 1) == 1)
        #expect(DailyGoal.rounds(ofTime: 0) == 1)
        #expect(DailyGoal.rounds(ofTime: 659) == 5)
        #expect(DailyGoal.rounds(ofTime: 660) == 6)
        #expect(DailyGoal.rounds(ofTime: 1800) == 15)
        #expect(DailyGoal.rounds(ofTime: 100_000) == 15)
        // Whatever the learner did: ten seconds of work leaves one round, ten thousand fifteen.
        let tiny = (0..<7).map { Day(day: $0, worked: 10, closed: true, studied: true) }
        #expect(DailyGoal.size(on: 7, after: tiny, rule: .follows).capacity == 1)
        let huge = (0..<7).map { Day(day: $0, worked: 10_000, closed: true, studied: true) }
        #expect(DailyGoal.size(on: 7, after: huge, rule: .follows).capacity == 15)
    }

    @Test func theRoundsRuleStepsOneRoundAtATimeFromTheDayBefore() {
        #expect(DailyGoal.size(on: 0, after: [], rule: .rounds).capacity == DailyGoal.initialCapacity)
        let twoClosed = [Day(day: 0, capacity: 4, worked: 0, closed: true, studied: true), Day(day: 1, capacity: 4, worked: 0, closed: true, studied: true)]
        #expect(DailyGoal.size(on: 2, after: twoClosed, rule: .rounds).capacity == 5)
        let oneClosed = [Day(day: 0, capacity: 4, worked: 0, closed: false, studied: true), Day(day: 1, capacity: 4, worked: 0, closed: true, studied: true)]
        #expect(DailyGoal.size(on: 2, after: oneClosed, rule: .rounds).capacity == 4)
        let open = [Day(day: 0, capacity: 4, worked: 0, closed: true, studied: true), Day(day: 1, capacity: 4, worked: 0, closed: false, studied: true)]
        #expect(DailyGoal.size(on: 2, after: open, rule: .rounds).capacity == 3)
        #expect(DailyGoal.size(on: 2, after: open, rule: .rounds).reason == nil)
    }
}
