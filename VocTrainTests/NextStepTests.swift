import Foundation
import Testing

@testable import VocTrain
@testable import VocabCore

/// The one sentence of the day: the next moment and its minutes, with no days in it, and the streak's line apart. The figures in,
/// the words out; two parts only where the ring is closed with cards left.
struct NextStepTests {
    func step(
        days: Int = 7, _ state: StreakState, closed: Bool = false, keep: Int? = nil, close: Int? = nil, reviews: Bool = false, left: Int? = nil
    ) -> NextStep {
        NextStep(days: days, state: state, isClosed: closed, minutesToKeep: keep, minutesToClose: close, reviewsLeft: reviews, minutesOfReviews: left)
    }

    @Test func theStreakStepOpenNamesTheTimeThatKeepsTheStreak() {
        let open = step(.open, keep: 2, close: 9)
        #expect(open.sentence == "≈ 2 min to keep your streak")
        #expect(open.lines == NextStep.Lines(lead: "≈ 2 min to keep your streak"), "one part: it wraps at words")
        #expect(open.minutes == 2 && open.short == "7 · ≈ 2 min")
        #expect(step(.open, keep: 0).sentence == "< 1 min to keep your streak")
        // No price: the moment alone.
        let free = step(.open)
        #expect(free.sentence == "Keep your streak" && free.minutes == nil && free.short == "7")
        // The days are not in the sentence: the streak line has them.
        #expect(!open.sentence.contains("7") && open.streakText == "7-day streak")
        #expect(open.streakSpoken == "7-day streak, not kept yet" && open.spoken == "7-day streak, not kept yet · ≈ 2 min to keep your streak")
    }

    @Test func withoutAStreakTheSameTimeStartsOne() {
        let fresh = step(days: 0, .open, keep: 2)
        #expect(fresh.sentence == "≈ 2 min to start your streak" && fresh.short == fresh.sentence)
        #expect(fresh.lines.tail == nil && fresh.spoken == fresh.sentence, "no streak, no streak line to speak")
        #expect(step(days: 0, .open).sentence == "Start your streak")
    }

    @Test func theStepDoneNamesTheTimeThatClosesTheRing() {
        // The first round's time is not read any more.
        let kept = step(.kept, keep: 2, close: 5)
        #expect(kept.sentence == "≈ 5 min to close the ring" && kept.lines.tail == nil)
        #expect(kept.minutes == 5 && kept.short == "7 · ≈ 5 min")
        #expect(kept.streakSpoken == "7-day streak, kept today")
        #expect(kept.spoken == "7-day streak, kept today · ≈ 5 min to close the ring")
        #expect(step(.kept).sentence == "Close the ring" && step(.kept).short == "7")
    }

    @Test func aClosedRingNamesTheReviewsLeftOrIsAllDone() {
        let reviews = step(.kept, closed: true, reviews: true, left: 12)
        #expect(reviews.sentence == "Ring closed · ≈ 12 min of reviews left")
        #expect(reviews.lines == NextStep.Lines(lead: "Ring closed", tail: "≈ 12 min of reviews left"))
        #expect(reviews.minutes == 12 && reviews.short == "7 · ≈ 12 min")
        // The cards are there, the price is not: the moment alone.
        #expect(step(.kept, closed: true, reviews: true).sentence == "Ring closed")
        let done = step(.kept, closed: true)
        #expect(done.sentence == "All done for today" && done.minutes == nil && done.short == "7 · Done")
        // No streak, nothing left: the sentence alone.
        let empty = step(days: 0, .open, closed: true)
        #expect(empty.sentence == "All done for today" && empty.short == "All done for today")
    }

    @Test func theDayAfterAMissedOneAsksForTheWholeRing() {
        let risk = step(.atRisk, keep: 2, close: 6)
        #expect(risk.sentence == "≈ 6 min to close the ring and save your streak")
        #expect(risk.lines.tail == nil)
        // The gauge and the short line count the ring's time, not the first round's.
        #expect(risk.minutes == 6 && risk.short == "7 · ≈ 6 min")
        #expect(risk.streakSpoken == "7-day streak, at risk")
        #expect(step(.atRisk).sentence == "Close the ring to save your streak")
    }

    /// A rest has the streak and the moment in its title and says the price under it.
    @Test func theRestSaysThePriceUnderItsTitle() {
        #expect(step(.kept, keep: 2, close: 5).priceLine == "≈ 5 min to close the ring")
        #expect(step(.kept, closed: true, reviews: true, left: 12).priceLine == "≈ 12 min of reviews left")
        #expect(step(.kept).priceLine == nil && step(.kept, closed: true, reviews: true).priceLine == nil)
        #expect(step(.kept, closed: true).priceLine == nil)
    }

    @Test func theTimeNeverBreaksAcrossLines() {
        #expect(NextStep.unbroken("≈ 2 min to keep your streak") == "≈\u{00A0}2\u{00A0}min to keep your streak")
        #expect(NextStep.unbroken("12-day streak") == "12\u{2011}day streak")
        #expect(NextStep.unbroken("< 1 min to close the ring") == "<\u{00A0}1\u{00A0}min to close the ring")
        #expect(
            NextStep.unbroken("≈ 6 min to close the ring and save your streak", endTogether: true)
                == "≈\u{00A0}6\u{00A0}min to close the ring and save your\u{00A0}streak")
        #expect(NextStep.unbroken("All done for today", endTogether: true) == "All done for\u{00A0}today")
        #expect(NextStep.unbroken("Done", endTogether: true) == "Done")
    }

    /// Today's second figure: the label names the moment, the value is its minutes.
    @Test func theNextMomentIsAFigureOfALabelAndMinutes() {
        typealias Moment = NextStep.Moment
        #expect(step(.open, keep: 2, close: 9).moment == Moment(label: "To keep your streak", value: "≈ 2 min"))
        #expect(step(.open, keep: 0).moment == Moment(label: "To keep your streak", value: "< 1 min"))
        #expect(step(.kept, keep: 2, close: 5).moment == Moment(label: "To close the ring", value: "≈ 5 min"))
        #expect(step(.atRisk, keep: 2, close: 6).moment == Moment(label: "To save your streak", value: "≈ 6 min"))
        #expect(step(days: 0, .open, keep: 2).moment == Moment(label: "To start your streak", value: "≈ 2 min"))
        #expect(step(.kept, closed: true, reviews: true, left: 12).moment == Moment(label: "Reviews left", value: "≈ 12 min"))
        #expect(step(.kept, closed: true).moment == Moment(label: "Today", value: "All done"))
        // A closed ring with cards left is the moment even without a streak.
        #expect(step(days: 0, .open, closed: true, reviews: true, left: 4).moment == Moment(label: "Reviews left", value: "≈ 4 min"))
        // Without a price the label is "Next" and the value the moment in words, never a dash.
        #expect(step(.open).moment == Moment(label: "Next", value: "Keep your streak"))
        #expect(step(.kept).moment == Moment(label: "Next", value: "Close the ring"))
        #expect(step(.atRisk).moment == Moment(label: "Next", value: "Save your streak"))
        #expect(step(days: 0, .open).moment == Moment(label: "Next", value: "Start your streak"))
        #expect(step(.kept, closed: true, reviews: true).moment == Moment(label: "Next", value: "Keep Going"))
    }

    /// A tinted widget draws every lap in one tone: past the goal the ring says its lap as a number.
    @Test func aRingPastItsGoalSaysItsLap() {
        #expect(DailyRingFigure.laps(0) == nil && DailyRingFigure.laps(0.9) == nil && DailyRingFigure.laps(1) == nil)
        #expect(DailyRingFigure.laps(1.4) == 2 && DailyRingFigure.laps(2) == 2)
        #expect(DailyRingFigure.laps(2.2) == 3 && DailyRingFigure.laps(ProgressRing.maxLaps) == 3)
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
        #expect(open.sentence.hasSuffix("to keep your streak"))
        let closedWithReviews = NextStep(day(done: 30, left: 40))
        let priced = day(done: 30, left: 40).minutesOfDueAfterRing
        #expect(closedWithReviews.isClosed && closedWithReviews.reviewsLeft && priced != nil && closedWithReviews.minutes == priced)
        #expect(closedWithReviews.sentence == "Ring closed · \(Format.timeLeft(minutes: priced ?? 0)) of reviews left")
        #expect(NextStep(day(done: 30, left: 0)).sentence == "All done for today")
    }
}
