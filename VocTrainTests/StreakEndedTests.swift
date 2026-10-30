import Foundation
import Testing

@testable import VocTrain
@testable import VocabCore

/// A streak that ended is told once on the first Today after the break (`EndedStreak`): the days it had and the best.
struct StreakEndedTests {
    /// The streak at the end of each day, from study day 100: a missed day leaves the streak it interrupted at risk, a
    /// second one in a row ends it (`Streak.walk`).
    func records(_ streaks: [Int]) -> [DayRecord] {
        streaks.enumerated().map { index, streak in
            DayRecord(day: 100 + index, done: 0, goal: 20, kept: false, closed: false, streak: streak)
        }
    }

    @Test func aStreakThatTwoMissedDaysEndedIsToldWithTheBest() throws {
        let streaks = Array(1...30) + [30, 0, 0] + Array(1...12) + [12, 0]
        let ended = try #require(EndedStreak.pending(records: records(streaks), current: 0, shown: 0))
        #expect(ended.days == 12)
        #expect(ended.best == 30)
        #expect(ended.day == 100 + streaks.count - 1)
        #expect(ended.text == "12-day streak ended · Best: 30")
    }

    @Test func theBestIsLeftOutWhenTheEndedStreakWasIt() throws {
        let ended = try #require(EndedStreak.pending(records: records(Array(1...12) + [12, 0]), current: 0, shown: 0))
        #expect(ended.text == "12-day streak ended")
    }

    @Test func aStreakSavedAfterAMissedDayHasNotEnded() {
        #expect(EndedStreak.pending(records: records(Array(1...12) + [12, 14]), current: 14, shown: 0) == nil)
        #expect(EndedStreak.pending(records: records(Array(1...12) + [12, 12]), current: 12, shown: 0) == nil)
    }

    @Test func aStreakRebuiltSinceSaysNothingOfTheOldOne() {
        #expect(EndedStreak.pending(records: records(Array(1...12) + [12, 0, 1, 2]), current: 2, shown: 0) == nil)
    }

    @Test func aNewStartAfterTheBreakStillTellsIt() throws {
        let ended = try #require(EndedStreak.pending(records: records(Array(1...12) + [12, 1]), current: 1, shown: 0))
        #expect(ended.days == 12)
    }

    @Test func aStreakOfOneDayEndsWithoutAWord() {
        #expect(EndedStreak.pending(records: records([1, 1, 0]), current: 0, shown: 0) == nil)
    }

    @Test func itIsToldOnce() throws {
        let streaks = Array(1...12) + [12, 0]
        let ended = try #require(EndedStreak.pending(records: records(streaks), current: 0, shown: 0))
        #expect(EndedStreak.pending(records: records(streaks), current: 0, shown: ended.day) == nil)
        // The next streak that ends is told again.
        let later = streaks + Array(1...5) + [5, 0]
        #expect(EndedStreak.pending(records: records(later), current: 0, shown: ended.day)?.days == 5)
    }
}
