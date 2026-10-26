import Foundation
import Testing

@testable import VocTrain
@testable import VocabCore

/// What the day tells: the streak to keep, and the words in memory. Rounds never show.
struct DayLinesTests {
    func line(_ title: LocalizedStringResource?) -> String? { title.map { String(localized: $0) } }

    @Test func theStreakCostsTheFirstRoundUntilItIsDone() {
        #expect(RoundStatus(rounds: 4, roundsDone: 0, minutesToNext: 2).minutesToKeep == 2)
        #expect(!RoundStatus(rounds: 4, roundsDone: 0, minutesToNext: 2).isStreakKept)
        #expect(RoundStatus(rounds: 4, roundsDone: 1, minutesToNext: 3).minutesToKeep == nil, "kept")
        #expect(RoundStatus(rounds: 4, roundsDone: 1, minutesToNext: 3).isStreakKept)
        #expect(RoundStatus(rounds: 4, roundsDone: 4, minutesToNext: nil).minutesToKeep == nil)
        #expect(RoundStatus(rounds: 0, roundsDone: 0, minutesToNext: nil).minutesToKeep == nil, "no plan, nothing to keep")
        #expect(RoundStatus(rounds: 0, roundsDone: 0, minutesToNext: nil).isStreakKept, "an empty plan keeps the streak")
    }

    @Test func theStatusReadsTheProgress() {
        let rounds = DayRounds(otherCards: 20, newCards: 0, pace: Pace(newCard: 30, otherCard: 15), seconds: 360)
        let progress = DailyProgress(ring: DailyRing(done: 9, goal: 20), streak: Streak(days: 1, repairCards: nil), roundPlan: rounds)
        // The streak step ends at 8 cards: 9 are done, and the goal ends at 20, eleven cards and 165 s on: three minutes up.
        #expect(RoundStatus(progress) == RoundStatus(rounds: 2, roundsDone: 1, minutesToNext: 3))
    }

    @Test func theWordsInMemoryAreShownRoundedDownWithTheDaysGain() {
        let memory = MemoryEstimate(words: 28.9, wordsAtDayStart: 13.3)
        #expect(line(memory.wordsLine) == "28 words in memory")
        #expect(line(memory.gainLine) == "+16 today")
        #expect(memory.line == "28 words in memory · +16 today")
        #expect(memory.milestoneLine == nil)
        // One word is a word.
        #expect(line(MemoryEstimate(words: 1.5, wordsAtDayStart: 0).wordsLine) == "1 word in memory")
    }

    @Test func aDayThatAddedNothingSaysNothingOfIt() {
        let memory = MemoryEstimate(words: 40, wordsAtDayStart: 40)
        #expect(memory.line == "40 words in memory")
        #expect(memory.gainLine == nil)
        // And before any word there is no line at all.
        #expect(MemoryEstimate(words: 0.4, wordsAtDayStart: 0).line == nil)
        #expect(MemoryEstimate(words: 0.4, wordsAtDayStart: 0).wordsLine == nil)
    }

    @Test func aMilestonePassedTodayIsAnnounced() {
        let memory = MemoryEstimate(words: 51.2, wordsAtDayStart: 47)
        #expect(line(memory.milestoneLine) == "50 words in memory!")
    }
}
