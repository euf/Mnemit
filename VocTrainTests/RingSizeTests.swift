import Testing

@testable import VocTrain
@testable import VocabCore

/// The line of Progress that names the learner's ring: today's size in minutes and, once it moved, the first day's.
struct RingSizeTests {
    /// A day whose ring asks `time` seconds, after a first study day that asked `first` (none: no study day yet).
    private func progress(time: Double, first: Double?) -> DailyProgress {
        DailyProgress(
            ring: DailyRing(done: 0, goal: 10), streak: Streak(days: 0, repairCards: nil), time: time,
            ringDays: first.map { [DailyGoal.RingDay(day: 1, time: $0, worked: 0, closed: true, studied: true)] } ?? [])
    }

    @Test func aRingThatGrewSaysWhereItStarted() {
        #expect(RingSize(progress(time: 480, first: 150)).line == "Your ring: 8 min a day · started at 2.5")
    }

    @Test func aRingThatShrankSaysSoToo() {
        #expect(RingSize(progress(time: 120, first: 300)).line == "Your ring: 2 min a day · started at 5")
    }

    @Test func aRingThatDidNotMoveHasNoStart() {
        #expect(RingSize(progress(time: 150, first: 150)).line == "Your ring: 2.5 min a day")
    }

    @Test func withoutAStudyDayTheStartIsToday() {
        #expect(RingSize(progress(time: 150, first: nil)).line == "Your ring: 2.5 min a day")
    }

    @Test func sizesThatAreTheSameInMinutesAreOne() {
        // 151.5 s is 2.525 min, which shows as 2.5, as the first day's 150 s.
        #expect(RingSize(progress(time: 151.5, first: 150)).line == "Your ring: 2.5 min a day")
    }

    @Test func minutesShowOneDecimalAtMost() {
        #expect(RingSize(progress(time: 200, first: 150)).line == "Your ring: 3.3 min a day · started at 2.5")
    }
}
