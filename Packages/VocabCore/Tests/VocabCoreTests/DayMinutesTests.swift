import Foundation
import Testing

@testable import VocabCore

/// The minutes the apps say: to the streak mark, to the ring, and of the due cards that stay after it, all at the
/// pace of the day.
struct DayMinutesTests {
    /// 10 seconds a due card, 30 a new one; a day of 5 minutes over 60 due and 10 new cards: the streak step ends at
    /// 12 cards (2 minutes), the ring at 30 (5 minutes).
    let pace = Pace(newCard: 30, otherCard: 10)

    func progress(done: Int, keptToday: Bool? = nil) -> DailyProgress {
        let plan = DayRounds(otherCards: 60, newCards: 10, pace: pace, seconds: 300)
        let left = 70 - done
        // Cards are done in plan order: the due ones first.
        let newLeft = min(10, left)
        return DailyProgress(
            ring: DailyRing(done: done, goal: plan.goal), streak: Streak(days: 3, repairCards: nil), cardsLeft: left, newCardsLeft: newLeft, pace: pace,
            time: 300, roundPlan: plan, streakKeptToday: keptToday ?? (done >= 12))
    }

    @Test func theMarksAreTwoMinutesAndFiveAndTheDueCardsBeyondTheRingStay() {
        let plan = DayRounds(otherCards: 60, newCards: 10, pace: pace, seconds: 300)
        #expect(plan.ends == [12, 30])
        let start = progress(done: 0)
        #expect(start.minutesToStreak == 2)
        #expect(start.minutesToRing == 5)
        // 60 due cards, 30 of them in the ring: 30 stay, 5 minutes of them.
        #expect(start.minutesOfDueAfterRing == 5)
    }

    @Test func theStreakMarkGoesOnceItIsReachedAndTheRestShrinks() {
        let step = progress(done: 12)
        #expect(step.minutesToStreak == nil)
        #expect(step.minutesToRing == 3)
        #expect(step.minutesOfDueAfterRing == 5)
        // Part of the way: the minutes to the mark are the cards left to it.
        let half = progress(done: 6)
        #expect(half.minutesToStreak == 1)
        #expect(half.minutesToRing == 4)
    }

    @Test func aClosedRingHasNoMinutesToItAndKeepsTheDueCardsThatStayed() {
        let closed = progress(done: 30)
        #expect(closed.minutesToStreak == nil)
        #expect(closed.minutesToRing == nil)
        #expect(closed.minutesOfDueAfterRing == 5)
        // The whole plan done leaves nothing to say.
        let none = DailyProgress(ring: DailyRing(done: 30, goal: 30), streak: Streak(days: 3, repairCards: nil), cardsLeft: 0, pace: pace, streakKeptToday: true)
        #expect(none.minutesToStreak == nil && none.minutesToRing == nil && none.minutesOfDueAfterRing == nil)
    }

    @Test func aDayWhoseGoalTakesTheWholePlanHasNoDueCardsAfterTheRing() {
        let plan = DayRounds(otherCards: 12, newCards: 0, pace: pace, seconds: 300)
        let day = DailyProgress(
            ring: DailyRing(done: 0, goal: plan.goal), streak: Streak(days: 1, repairCards: nil), cardsLeft: 12, newCardsLeft: 0, pace: pace, time: 300,
            roundPlan: plan)
        #expect(day.minutesToRing == 2)
        #expect(day.minutesOfDueAfterRing == nil)
    }
}
