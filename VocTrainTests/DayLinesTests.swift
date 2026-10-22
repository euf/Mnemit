import Foundation
import Testing

@testable import VocTrain
@testable import VocabCore

/// The lines the day is told in: the round the learner is in, and the words in memory.
struct DayLinesTests {
    func line(_ title: LocalizedStringResource?) -> String? { title.map { String(localized: $0) } }

    @Test func beforeTheFirstRoundTheLineIsTheTimeToKeepTheStreak() {
        let status = RoundStatus(rounds: 4, roundsDone: 0, minutesToNext: 2)
        #expect(line(status.title) == "≈ 2 min to keep your streak")
        #expect(status.time == nil)
        #expect(status.line == "≈ 2 min to keep your streak")
        #expect(!status.isStreakKept)
        #expect(line(RoundStatus(rounds: 4, roundsDone: 0, minutesToNext: 0).title) == "< 1 min to keep your streak")
    }

    @Test func betweenRoundsTheLineIsTheRoundWithItsTime() {
        let status = RoundStatus(rounds: 4, roundsDone: 1, minutesToNext: 2)
        #expect(line(status.title) == "Round 2 of 4")
        #expect(line(status.round) == "Round 2 of 4")
        #expect(status.time == "≈ 2 min")
        #expect(status.line == "Round 2 of 4 · ≈ 2 min")
        #expect(status.current == 2)
        #expect(status.isStreakKept)
    }

    @Test func afterTheLastRoundTheRingIsClosed() {
        let status = RoundStatus(rounds: 4, roundsDone: 4, minutesToNext: nil)
        #expect(status.isClosed)
        #expect(line(status.title) == "Ring closed")
        #expect(status.time == nil && status.round == nil && status.current == nil)
        #expect(status.line == "Ring closed")
    }

    @Test func aDayWithoutARoundHasNoLineAndKeepsTheStreak() {
        let status = RoundStatus(rounds: 0, roundsDone: 0, minutesToNext: nil)
        #expect(!status.hasRounds && !status.isClosed)
        #expect(status.title == nil && status.line == nil)
        #expect(status.isStreakKept)
    }

    @Test func theStatusReadsTheProgress() {
        let rounds = DayRounds(otherCards: 20, newCards: 0, pace: Pace(newCard: 30, otherCard: 15), capacity: 3)
        let progress = DailyProgress(ring: DailyRing(done: 9, goal: 20), streak: Streak(days: 1, repairCards: nil), roundPlan: rounds)
        // Round 1 ends at 8 cards: 9 are done, and the second ends at 16, seven cards and 105 s on.
        #expect(RoundStatus(progress) == RoundStatus(rounds: 3, roundsDone: 1, minutesToNext: 2))
    }

    @Test func theWordsInMemoryAreShownRoundedDownWithTheDaysGain() {
        let memory = MemoryEstimate(words: 28.9, wordsAtDayStart: 13.3)
        #expect(line(memory.wordsLine) == "≈ 28 words in memory")
        #expect(line(memory.gainLine) == "+16 today")
        #expect(memory.line == "≈ 28 words in memory · +16 today")
        #expect(line(memory.gainSentence) == "+16 words in memory today")
        #expect(memory.milestoneLine == nil)
        // One word is a word.
        #expect(line(MemoryEstimate(words: 1.5, wordsAtDayStart: 0).wordsLine) == "≈ 1 word in memory")
    }

    @Test func aDayThatAddedNothingSaysNothingOfIt() {
        let memory = MemoryEstimate(words: 40, wordsAtDayStart: 40)
        #expect(memory.line == "≈ 40 words in memory")
        #expect(memory.gainLine == nil && memory.gainSentence == nil)
        // And before any word there is no line at all.
        #expect(MemoryEstimate(words: 0.4, wordsAtDayStart: 0).line == nil)
        #expect(MemoryEstimate(words: 0.4, wordsAtDayStart: 0).wordsLine == nil)
    }

    @Test func aMilestonePassedTodayIsAnnounced() {
        let memory = MemoryEstimate(words: 51.2, wordsAtDayStart: 47)
        #expect(line(memory.milestoneLine) == "50 words in memory!")
    }
}
