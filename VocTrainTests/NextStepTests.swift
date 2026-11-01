import Foundation
import Testing

@testable import VocTrain
@testable import VocabCore

/// The next step of the day: an action and its price, with no days in it, and the streak's line apart. The figures in, the
/// words out.
struct NextStepTests {
    /// A price as `Format.timeLeft` writes it: its spaces do not break.
    func min(_ text: String) -> String { text.replacingOccurrences(of: " ", with: "\u{00A0}") }

    func step(
        days: Int = 7, _ state: StreakState, closed: Bool = false, keep: Int? = nil, close: Int? = nil, reviews: Bool = false, left: Int? = nil
    ) -> NextStep {
        NextStep(days: days, state: state, isClosed: closed, minutesToKeep: keep, minutesToClose: close, reviewsLeft: reviews, minutesOfReviews: left)
    }

    @Test func theStreakStepOpenNamesTheTimeThatKeepsTheStreak() {
        let open = step(.open, keep: 2, close: 9)
        #expect(open.action == "Keep your streak" && open.price == min("2 min"))
        #expect(open.sentence == "Keep your streak · " + min("2 min"))
        #expect(open.minutes == 2 && open.short == "7 · " + min("2 min"))
        #expect(step(.open, keep: 0).sentence == "Keep your streak · " + min("< 1 min"))
        // No price: the action alone.
        let free = step(.open)
        #expect(free.sentence == "Keep your streak" && free.minutes == nil && free.price == nil && free.short == "7 · Keep your streak")
        // The days are not in the sentence: the streak line has them.
        #expect(!open.sentence.contains("7") && open.streakText == "7-day streak")
        #expect(open.streakSpoken == "7-day streak, not kept yet" && open.spoken == "7-day streak, not kept yet · Keep your streak · " + min("2 min"))
    }

    @Test func withoutAStreakTheSameTimeStartsOne() {
        let fresh = step(days: 0, .open, keep: 2)
        #expect(fresh.sentence == "Start your streak · " + min("2 min") && fresh.short == fresh.sentence)
        #expect(fresh.spoken == fresh.sentence, "no streak, no streak line to speak")
        #expect(step(days: 0, .open).sentence == "Start your streak")
    }

    @Test func theStepDoneNamesTheTimeThatClosesTheRing() {
        // The first round's time is not read any more.
        let kept = step(.kept, keep: 2, close: 5)
        #expect(kept.sentence == "Close your ring · " + min("5 min"))
        #expect(kept.minutes == 5 && kept.short == "7 · " + min("5 min"))
        #expect(kept.streakSpoken == "7-day streak, kept today")
        #expect(kept.spoken == "7-day streak, kept today · Close your ring · " + min("5 min"))
        #expect(step(.kept).sentence == "Close your ring" && step(.kept).short == "7 · Close your ring")
    }

    @Test func aClosedRingNamesTheReviewsLeftOrIsAllDone() {
        let reviews = step(.kept, closed: true, reviews: true, left: 12)
        #expect(reviews.sentence == "Finish your reviews · " + min("12 min"))
        #expect(reviews.minutes == 12 && reviews.short == "7 · " + min("12 min"))
        // The cards are there, the price is not: the action alone.
        #expect(step(.kept, closed: true, reviews: true).sentence == "Finish your reviews")
        let done = step(.kept, closed: true)
        #expect(done.sentence == "All done for today" && done.minutes == nil && done.price == nil && done.short == "7 · Done")
        // No streak, nothing left: the sentence alone.
        let empty = step(days: 0, .open, closed: true)
        #expect(empty.sentence == "All done for today" && empty.short == "All done for today")
    }

    @Test func theDayAfterAMissedOneAsksForTheWholeRing() {
        let risk = step(.atRisk, keep: 2, close: 6)
        // The action names what is at stake; its minutes are the ring's, which saves the streak.
        #expect(risk.sentence == "Save your streak · " + min("6 min"))
        // The gauge and the short line count the ring's time, not the first round's.
        #expect(risk.minutes == 6 && risk.short == "7 · " + min("6 min"))
        #expect(risk.streakSpoken == "7-day streak, at risk")
        #expect(step(.atRisk).sentence == "Save your streak")
    }

    /// A rest has the streak and the moment in its title and says the next step under it.
    @Test func theRestSaysThePriceUnderItsTitle() {
        #expect(step(.kept, keep: 2, close: 5).priceLine == "Close your ring · " + min("5 min"))
        #expect(step(.kept, closed: true, reviews: true, left: 12).priceLine == "Finish your reviews · " + min("12 min"))
        #expect(step(.kept).priceLine == nil && step(.kept, closed: true, reviews: true).priceLine == nil)
        #expect(step(.kept, closed: true).priceLine == nil)
    }

    @Test func theTimeNeverBreaksAcrossLines() {
        #expect(Format.timeLeft(minutes: 2) == "2\u{00A0}min" && Format.timeLeft(minutes: 0) == "<\u{00A0}1\u{00A0}min")
        #expect(NextStep.unbroken("12-day streak") == "12\u{2011}day streak")
        #expect(NextStep.unbroken("Finish your reviews", endTogether: true) == "Finish your\u{00A0}reviews")
        #expect(NextStep.unbroken("All done for today", endTogether: true) == "All done for\u{00A0}today")
        #expect(NextStep.unbroken("Done", endTogether: true) == "Done")
    }

    /// Today's second figure: the action over its price.
    @Test func theNextMomentIsAFigureOfAnActionAndItsPrice() {
        typealias Moment = NextStep.Moment
        #expect(step(.open, keep: 2, close: 9).moment == Moment(label: "Keep your streak", value: min("2 min")))
        #expect(step(.open, keep: 0).moment == Moment(label: "Keep your streak", value: min("< 1 min")))
        #expect(step(.kept, keep: 2, close: 5).moment == Moment(label: "Close your ring", value: min("5 min")))
        #expect(step(.atRisk, keep: 2, close: 6).moment == Moment(label: "Save your streak", value: min("6 min")))
        #expect(step(days: 0, .open, keep: 2).moment == Moment(label: "Start your streak", value: min("2 min")))
        #expect(step(.kept, closed: true, reviews: true, left: 12).moment == Moment(label: "Finish your reviews", value: min("12 min")))
        #expect(step(.kept, closed: true).moment == Moment(label: "Today", value: "All done"))
        // A closed ring with cards left is the moment even without a streak.
        #expect(step(days: 0, .open, closed: true, reviews: true, left: 4).moment == Moment(label: "Finish your reviews", value: min("4 min")))
        // Without a price the label is "Next" and the value the action, never a dash.
        #expect(step(.open).moment == Moment(label: "Next", value: "Keep your streak"))
        #expect(step(.kept).moment == Moment(label: "Next", value: "Close your ring"))
        #expect(step(.atRisk).moment == Moment(label: "Next", value: "Save your streak"))
        #expect(step(days: 0, .open).moment == Moment(label: "Next", value: "Start your streak"))
        #expect(step(.kept, closed: true, reviews: true).moment == Moment(label: "Next", value: "Finish your reviews"))
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
        #expect(open.action == "Keep your streak")
        let closedWithReviews = NextStep(day(done: 30, left: 40))
        let priced = day(done: 30, left: 40).minutesOfDueAfterRing
        #expect(closedWithReviews.isClosed && closedWithReviews.reviewsLeft && priced != nil && closedWithReviews.minutes == priced)
        #expect(closedWithReviews.sentence == "Finish your reviews · \(Format.timeLeft(minutes: priced ?? 0))")
        #expect(NextStep(day(done: 30, left: 0)).sentence == "All done for today")
    }
}

/// The words of Today's one button: the three stages are the rests' words, and none of them draws grey.
struct DayActionTests {
    @Test func theStagesAreStudyKeepGoingAndLearnTenNewWords() {
        func key(_ action: DayAction) -> String? {
            Mirror(reflecting: action.title).children.first { $0.label == "key" }?.value as? String
        }
        #expect(key(.study) == "Study")
        #expect(key(.catchUp) == "Keep Going")
        #expect(key(.pushOn) == "Learn 10 New Words")
    }
}
