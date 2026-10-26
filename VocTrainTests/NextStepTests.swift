import Foundation
import Testing

@testable import VocTrain
@testable import VocabCore

/// The one sentence of the day: the next moment and its minutes, led by the flame. The figures in, the flame and the words out,
/// in two parts where it has a streak line and a price line.
struct NextStepTests {
    func step(
        days: Int = 7, _ state: StreakState, closed: Bool = false, keep: Int? = nil, close: Int? = nil, reviews: Bool = false, left: Int? = nil
    ) -> NextStep {
        NextStep(days: days, state: state, isClosed: closed, minutesToKeep: keep, minutesToClose: close, reviewsLeft: reviews, minutesOfReviews: left)
    }

    @Test func theStreakStepOpenNamesTheTimeThatKeepsTheStreak() {
        let open = step(.open, keep: 2, close: 9)
        #expect(open.sentence == "≈ 2 min to keep your 7-day streak" && open.flame == .open)
        #expect(open.lines == NextStep.Lines(lead: "≈ 2 min to keep your 7-day streak"), "one part: it wraps at words")
        #expect(open.minutes == 2 && open.short == "7 · ≈ 2 min")
        #expect(step(.open, keep: 0).sentence == "< 1 min to keep your 7-day streak")
        // No price: the streak alone.
        let free = step(.open)
        #expect(free.sentence == "7-day streak" && free.minutes == nil && free.short == "7")
        #expect(free.spoken == "7-day streak, not kept yet")
    }

    @Test func withoutAStreakTheSameTimeStartsOne() {
        let fresh = step(days: 0, .open, keep: 2)
        #expect(fresh.sentence == "Start your streak · ≈ 2 min" && fresh.flame == .open && fresh.short == fresh.sentence)
        #expect(fresh.lines == NextStep.Lines(lead: "Start your streak", tail: "≈ 2 min"), "two parts, broken between the streak and the price")
        #expect(step(days: 0, .open).sentence == "Start your streak")
    }

    @Test func theStepDoneNamesTheTimeThatClosesTheRing() {
        // The first round's time is not read any more.
        let kept = step(.kept, keep: 2, close: 5)
        #expect(kept.sentence == "7-day streak · ≈ 5 min to close the ring" && kept.flame == .kept)
        #expect(kept.lines == NextStep.Lines(lead: "7-day streak", tail: "≈ 5 min to close the ring"))
        #expect(kept.minutes == 5 && kept.short == "7 · ≈ 5 min")
        #expect(kept.spoken == "7-day streak, kept today · ≈ 5 min to close the ring")
        #expect(step(.kept).sentence == "7-day streak" && step(.kept).short == "7")
    }

    @Test func aClosedRingNamesTheReviewsLeftOrIsAllDone() {
        let reviews = step(.kept, closed: true, reviews: true, left: 12)
        #expect(reviews.sentence == "Ring closed · ≈ 12 min of reviews left" && reviews.flame == .kept)
        #expect(reviews.lines == NextStep.Lines(lead: "Ring closed", tail: "≈ 12 min of reviews left"))
        #expect(reviews.minutes == 12 && reviews.short == "7 · ≈ 12 min")
        // The cards are there, the price is not: the moment alone.
        #expect(step(.kept, closed: true, reviews: true).sentence == "Ring closed")
        let done = step(.kept, closed: true)
        #expect(done.sentence == "All done for today" && done.flame == .kept)
        #expect(done.minutes == nil && done.short == "7 · Done")
        // No streak, nothing left: nothing to light.
        let empty = step(days: 0, .open, closed: true)
        #expect(empty.sentence == "All done for today" && empty.flame == nil && empty.short == "All done for today")
    }

    @Test func theDayAfterAMissedOneAsksForTheWholeRing() {
        let risk = step(.atRisk, keep: 2, close: 6)
        #expect(risk.sentence == "≈ 6 min to close the ring and save your 7-day streak" && risk.flame == .atRisk)
        #expect(risk.lines.tail == nil)
        // The gauge and the short line count the ring's time, not the first round's.
        #expect(risk.minutes == 6 && risk.short == "7 · ≈ 6 min")
        #expect(step(.atRisk).sentence == "Close the ring to save your 7-day streak")
    }

    @Test func theTimeNeverBreaksAcrossLines() {
        #expect(NextStep.unbroken("≈ 2 min to keep your 12-day streak") == "≈\u{00A0}2\u{00A0}min to keep your 12\u{2011}day streak")
        #expect(NextStep.unbroken("< 1 min to close the ring") == "<\u{00A0}1\u{00A0}min to close the ring")
    }

    @Test func theFiguresOfADayGiveTheSameStep() {
        func day(done: Int, left: Int, kept: Bool, repair: Int? = nil) -> DailyProgress {
            DailyProgress(ring: DailyRing(done: done, goal: 20), streak: Streak(days: 7, repairCards: repair), cardsLeft: left, streakKeptToday: kept)
        }
        #expect(NextStep(day(done: 3, left: 17, kept: false), minutesToKeep: 2, minutesToClose: 3, minutesOfReviews: nil) == step(.open, keep: 2, close: 3, reviews: true))
        #expect(NextStep(day(done: 12, left: 8, kept: true), minutesToKeep: nil, minutesToClose: 2, minutesOfReviews: nil) == step(.kept, close: 2, reviews: true))
        #expect(NextStep(day(done: 20, left: 5, kept: true), minutesToKeep: nil, minutesToClose: nil, minutesOfReviews: 1) == step(.kept, closed: true, reviews: true, left: 1))
        #expect(NextStep(day(done: 20, left: 0, kept: true), minutesToKeep: nil, minutesToClose: nil, minutesOfReviews: nil) == step(.kept, closed: true))
        #expect(NextStep(day(done: 3, left: 17, kept: true, repair: 17), minutesToKeep: nil, minutesToClose: 3, minutesOfReviews: nil) == step(.atRisk, close: 3, reviews: true))
    }

    /// The figures from the core: the plan of 30 cards in 4 rounds, 10 s a card, the streak step at the first round.
    @Test func theCoreFiguresGiveTheMoments() {
        let rounds = DayRounds(otherCards: 30, newCards: 0, pace: Pace(newCard: 30, otherCard: 15), seconds: 480)
        func day(done: Int, left: Int) -> DailyProgress {
            DailyProgress(ring: DailyRing(done: done, goal: 30), streak: Streak(days: 12, repairCards: nil), cardsLeft: left, roundPlan: rounds)
        }
        let open = NextStep(day(done: 2, left: 28))
        #expect(open.minutesToKeep != nil && open.state == .open && !open.isClosed)
        #expect(open.sentence.hasSuffix("to keep your 12-day streak"))
        let closedWithReviews = NextStep(day(done: 30, left: 40))
        let priced = day(done: 30, left: 40).minutesOfDueAfterRing
        #expect(closedWithReviews.isClosed && closedWithReviews.reviewsLeft && priced != nil && closedWithReviews.minutes == priced)
        #expect(closedWithReviews.sentence == "Ring closed · \(Format.timeLeft(minutes: priced ?? 0)) of reviews left")
        #expect(NextStep(day(done: 30, left: 0)).sentence == "All done for today")
    }
}
