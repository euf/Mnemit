import Foundation
import Testing

@testable import VocTrain
@testable import VocabCore

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

    /// The widget's snapshot holds only the figures, and says what Today says from them.
    @Test func theFiguresAloneGiveTheSameLead() {
        let progress = day(done: 10)
        let alone = TodayLead.text(
            due: 20, ring: progress.ring, secondsPerCard: progress.secondsPerCardLeft, nextDue: nil, now: now)
        #expect(alone == lead(due: 20, progress))
        // Without a price there is no time.
        #expect(TodayLead.text(due: 20, ring: progress.ring, secondsPerCard: nil, nextDue: nil, now: now) == nil)
    }
}
