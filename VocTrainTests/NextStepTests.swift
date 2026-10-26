import Foundation
import Testing

@testable import VocTrain
@testable import VocabCore

/// The one sentence of the day, the streak and the price of the next step, led by the flame: the figures in, the flame and
/// the words out.
struct NextStepTests {
    func step(days: Int = 7, _ state: StreakState, closed: Bool = false, keep: Int? = nil, close: Int? = nil) -> NextStep {
        NextStep(days: days, state: state, isClosed: closed, minutesToKeep: keep, minutesToClose: close)
    }

    @Test func theStreakStepOpenNamesTheTimeThatKeepsTheStreak() {
        let open = step(.open, keep: 2, close: 9)
        #expect(open.sentence == "≈ 2 min to keep your 7-day streak" && open.flame == .open)
        #expect(open.minutes == 2 && open.short == "7 · ≈ 2 min")
        #expect(step(.open, keep: 0).sentence == "< 1 min to keep your 7-day streak")
        // No price: the streak alone.
        let free = step(.open)
        #expect(free.sentence == "7-day streak" && free.minutes == nil && free.short == "7")
    }

    @Test func withoutAStreakTheSameTimeStartsOne() {
        let fresh = step(days: 0, .open, keep: 2)
        #expect(fresh.sentence == "Start your streak · ≈ 2 min" && fresh.flame == .open && fresh.short == fresh.sentence)
        #expect(step(days: 0, .open).sentence == "Start your streak")
    }

    @Test func theStepDoneNamesTheTimeThatClosesTheRing() {
        // The first round's time is not read any more.
        let kept = step(.kept, keep: 2, close: 5)
        #expect(kept.sentence == "7-day streak · ≈ 5 min left" && kept.flame == .kept)
        #expect(kept.minutes == 5 && kept.short == "7 · ≈ 5 min")
        #expect(step(.kept).sentence == "7-day streak" && step(.kept).short == "7")
    }

    @Test func aClosedRingIsDoneForToday() {
        let closed = step(.kept, closed: true, close: 7)
        #expect(closed.sentence == "7-day streak · Done for today" && closed.flame == .kept)
        #expect(closed.minutes == nil && closed.short == "7 · Done")
        // No streak, nothing left: nothing to light.
        let empty = step(days: 0, .open, closed: true)
        #expect(empty.sentence == "Done for today" && empty.flame == nil && empty.short == "Done for today")
    }

    @Test func theDayAfterAMissedOneAsksForTheWholeRing() {
        let risk = step(.atRisk, keep: 2, close: 6)
        #expect(risk.sentence == "Close the ring to save your 7-day streak" && risk.flame == .atRisk)
        // The gauge and the short line count the ring's time, not the first round's.
        #expect(risk.minutes == 6 && risk.short == "7 · ≈ 6 min")
    }

    @Test func theFiguresOfADayGiveTheSameStep() {
        func day(done: Int, left: Int, kept: Bool, repair: Int? = nil) -> DailyProgress {
            DailyProgress(ring: DailyRing(done: done, goal: 20), streak: Streak(days: 7, repairCards: repair), cardsLeft: left, streakKeptToday: kept)
        }
        #expect(NextStep(day(done: 3, left: 17, kept: false), minutesToKeep: 2, minutesToClose: 3) == step(.open, keep: 2, close: 3))
        #expect(NextStep(day(done: 12, left: 8, kept: true), minutesToKeep: nil, minutesToClose: 2) == step(.kept, close: 2))
        #expect(NextStep(day(done: 20, left: 5, kept: true), minutesToKeep: nil, minutesToClose: nil) == step(.kept, closed: true))
        #expect(NextStep(day(done: 3, left: 17, kept: true, repair: 17), minutesToKeep: nil, minutesToClose: 3) == step(.atRisk, close: 3))
    }
}
