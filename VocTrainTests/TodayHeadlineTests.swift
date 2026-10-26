import Foundation
import Testing

@testable import VocTrain
@testable import VocabCore

/// The one line under Today's ring by the state of the day. The day is four rounds over 30 cards, which end at 8, 16,
/// 24 and 30; `due` is what is left of the plan.
struct TodayHeadlineTests {
    /// The real clock: `Format.due` words a date relative to the system's now.
    let now = Date()

    func day(done: Int, repairCards: Int? = nil) -> DailyProgress {
        let rounds = DayRounds(otherCards: 30, newCards: 0, pace: Pace(newCard: 30, otherCard: 15), seconds: 480)
        return DailyProgress(
            ring: DailyRing(done: done, goal: rounds.goal), streak: Streak(days: 12, repairCards: repairCards), pace: Pace(newCard: 30, otherCard: 15),
            roundPlan: rounds, streakKeptToday: rounds.roundsDone(cardsDone: done) > 0)
    }

    func headline(due: Int, _ progress: DailyProgress, nextDue: Date? = nil) -> String {
        TodayHeadline.text(due: due, progress: progress, nextDue: nextDue, now: now)
    }

    @Test func beforeTheStreakStepTheTimeToKeepTheStreak() {
        let text = headline(due: 27, day(done: 3))
        #expect(text.hasPrefix("≈ ") && text.hasSuffix(" min to keep your streak"), "\(text)")
    }

    @Test func afterTheStreakStepTheCardsLeftWithTheirTime() {
        let text = headline(due: 20, day(done: 10))
        #expect(text.hasPrefix("20 cards left · ≈ ") && text.hasSuffix(" min"), "\(text)")
    }

    @Test func theCardsToTheRingCountNotTheWholePlan() {
        // 28 of 30 done, 40 left in the plan: two cards close the ring.
        #expect(headline(due: 40, day(done: 28)).hasPrefix("2 cards left"))
    }

    @Test func aClosedRingSaysWhatIsLeftOfThePlan() {
        #expect(headline(due: 3, day(done: 31)) == "Ring closed · 3 left")
    }

    @Test func aDoneDayIsDone() {
        #expect(headline(due: 0, day(done: 31)) == "All done")
        #expect(headline(due: 0, day(done: 31), nextDue: now.addingTimeInterval(86_400)) == "All done")
    }

    @Test func aDayWithNothingDueNamesTheNextReview() {
        #expect(headline(due: 0, day(done: 0), nextDue: now.addingTimeInterval(86_400)) == "Nothing due · next tomorrow")
        #expect(headline(due: 0, day(done: 0)) == "Nothing due")
    }

    @Test func theDayAfterAMissedOneAsksForTheRing() {
        #expect(headline(due: 20, day(done: 10, repairCards: 15)) == "Close the ring to save your 12-day streak")
        #expect(headline(due: 3, day(done: 31, repairCards: 15)) == "Ring closed · 3 left", "the closed ring saved it")
    }
}

/// What leads the gain line under the streak chip: the ring says the cards left and the chip the streak, so the line
/// has the time, what the plan holds beyond a closed ring, or the next review.
struct TodayLeadTests {
    let now = Date()

    func day(done: Int) -> DailyProgress {
        let rounds = DayRounds(otherCards: 30, newCards: 0, pace: Pace(newCard: 30, otherCard: 15), seconds: 480)
        return DailyProgress(
            ring: DailyRing(done: done, goal: rounds.goal), streak: Streak(days: 12, repairCards: nil), pace: Pace(newCard: 30, otherCard: 15),
            roundPlan: rounds, streakKeptToday: rounds.roundsDone(cardsDone: done) > 0)
    }

    func lead(due: Int, _ progress: DailyProgress, nextDue: Date? = nil) -> String? {
        TodayLead.text(due: due, progress: progress, nextDue: nextDue, now: now)
    }

    @Test func anOpenRingHasTheTimeThatClosesIt() {
        let text = lead(due: 20, day(done: 10))
        #expect(text?.hasPrefix("≈ ") == true && text?.hasSuffix(" min") == true, "\(text ?? "nil")")
        #expect(lead(due: 20, day(done: 10)) == lead(due: 40, day(done: 10)), "the cards to the ring, not the whole plan")
    }

    @Test func aClosedRingSaysWhatTheCardsLeftOfThePlan() {
        #expect(lead(due: 3, day(done: 31)) == "3 left")
    }

    @Test func aDoneDayHasNoLead() {
        #expect(lead(due: 0, day(done: 31)) == nil)
        #expect(lead(due: 0, day(done: 31), nextDue: now.addingTimeInterval(86_400)) == nil)
    }

    @Test func aDayWithNothingDueNamesTheNextReview() {
        #expect(lead(due: 0, day(done: 0), nextDue: now.addingTimeInterval(86_400)) == "Nothing due · next tomorrow")
        #expect(lead(due: 0, day(done: 0)) == "Nothing due")
    }
}
