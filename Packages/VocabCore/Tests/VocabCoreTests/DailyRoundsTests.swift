import Foundation
import Testing

@testable import VocabCore

/// The day's time and where it ends: the streak step and the goal in cards, how many new cards the time admits,
/// and the rounds of the earlier rule (`DailyGoal.RingRule.rounds`).
struct DailyRoundsTests {
    /// A learner whose new card takes 30 s and any other 10 s.
    let pace = Pace(newCard: 30, otherCard: 10)

    // MARK: Capacity

    @Test func theStreakStepIsTwoMinutesAndTheFirstDayHoldsFour() {
        #expect(DailyGoal.streakSeconds == 120)
        #expect(DailyGoal.initialSeconds == 240)
        #expect(DailyGoal.timeRange == 120...1800)
        // The rounds rule: two rounds of the step to begin with, one to fifteen.
        #expect(DailyGoal.initialCapacity == 2)
        #expect(DailyGoal.capacityRange == 1...15)
    }

    @Test func twoClosedDaysInARowAddARound() {
        #expect(DailyGoal.nextCapacity(after: 2, yesterdayClosed: true, dayBeforeClosed: true) == 3)
        #expect(DailyGoal.nextCapacity(after: 7, yesterdayClosed: true, dayBeforeClosed: true) == 8)
    }

    @Test func anOpenDayTakesARoundAwayWhateverCameBefore() {
        #expect(DailyGoal.nextCapacity(after: 5, yesterdayClosed: false, dayBeforeClosed: true) == 4)
        #expect(DailyGoal.nextCapacity(after: 5, yesterdayClosed: false, dayBeforeClosed: false) == 4)
    }

    @Test func aSingleClosedDayAfterAnOpenOneLeavesTheCapacity() {
        #expect(DailyGoal.nextCapacity(after: 4, yesterdayClosed: true, dayBeforeClosed: false) == 4)
    }

    @Test func theCapacityStaysBetweenOneAndFifteen() {
        #expect(DailyGoal.nextCapacity(after: 1, yesterdayClosed: false, dayBeforeClosed: false) == 1)
        #expect(DailyGoal.nextCapacity(after: 15, yesterdayClosed: true, dayBeforeClosed: true) == 15)
        #expect(DailyGoal.nextCapacity(after: 14, yesterdayClosed: true, dayBeforeClosed: true) == 15)
    }

    // MARK: Admission

    @Test func newCardsFillTheTimeThatTheReviewsLeave() {
        // 240 s: 60 reviews take 150 s at 10 s a card, 90 s are left for new cards of 30 s.
        #expect(DailyGoal.newCardsAllowed(seconds: 2 * 120, otherCards: 15, pace: pace) == 3)
        #expect(DailyGoal.newCardsAllowed(seconds: 2 * 120, otherCards: 0, pace: pace) == 8)
        #expect(DailyGoal.newCardsAllowed(seconds: 5 * 120, otherCards: 20, pace: pace) == 13)
    }

    @Test func aDayWithMoreReviewsThanItsTimeAdmitsNoNewCards() {
        #expect(DailyGoal.newCardsAllowed(seconds: 2 * 120, otherCards: 24, pace: pace) == 0)
        #expect(DailyGoal.newCardsAllowed(seconds: 2 * 120, otherCards: 25, pace: pace) == 0)
        #expect(DailyGoal.newCardsAllowed(seconds: 1 * 120, otherCards: 500, pace: pace) == 0)
    }

    @Test func aSliverOfTimeDoesNotAdmitACard() {
        // 240 − 23 × 10 = 10 s: a third of a new card.
        #expect(DailyGoal.newCardsAllowed(seconds: 2 * 120, otherCards: 23, pace: pace) == 0)
        #expect(DailyGoal.newCardsAllowed(seconds: 2 * 120, otherCards: 21, pace: pace) == 1)
    }

    @Test func theAllowanceIsSharedByTheCeilingsOfTheDecksByLargestRemainder() {
        // 10 over 30 : 20 : 10 is 5 : 3.33 : 1.67, the rounded-down parts leave 1 card, for the largest remainder.
        #expect(DailyGoal.split(10, overCeilings: [30, 20, 10]) == [5, 3, 2])
        #expect(DailyGoal.split(8, overCeilings: [1, 1001]) == [0, 8])
        // Equal remainders: the earlier deck first.
        #expect(DailyGoal.split(1, overCeilings: [5, 5]) == [1, 0])
        #expect(DailyGoal.split(0, overCeilings: [5, 5]) == [0, 0])
    }

    @Test func noDeckGetsMoreThanItsCeilingAndAnAllowanceBeyondTheirSumLeavesThemWhole() {
        #expect(DailyGoal.split(100, overCeilings: [7, 3, 0]) == [7, 3, 0])
        #expect(DailyGoal.split(10, overCeilings: [7, 3, 0]) == [7, 3, 0])
        #expect(DailyGoal.split(9, overCeilings: [7, 3, 0]) == [6, 3, 0])
        #expect(DailyGoal.split(5, overCeilings: []) == [])
    }

    @Test func theSplitAddsUpToTheAllowanceWhenTheCeilingsAreEnoughForIt() {
        for total in 0...40 {
            for ceilings in [[10, 10, 10], [1, 2, 37], [0, 12, 13], [40]] {
                let parts = DailyGoal.split(total, overCeilings: ceilings)
                #expect(parts.reduce(0, +) == min(total, ceilings.reduce(0, +)))
                #expect(zip(parts, ceilings).allSatisfy { $0 <= $1 })
            }
        }
    }

    // MARK: The streak step and the goal

    @Test func aPlanOfNewCardsHasTheStreakStepAtTheFirstCardThatReachesTwoMinutes() {
        let rounds = DayRounds(otherCards: 0, newCards: 8, pace: pace, seconds: 240)
        #expect(rounds.ends == [4, 8])
        #expect(rounds.goal == 8)
        #expect(rounds.rounds == 2)
    }

    @Test func aMixOfReviewsAndNewCardsHasItsStreakStepAtTheFirstCardThatReachesTwoMinutes() {
        // 10 s a review: 12 reviews take 120 s: the streak step. The five new cards of 30 s fit the 360 s: the goal.
        let rounds = DayRounds(otherCards: 12, newCards: 5, pace: pace, seconds: 360)
        #expect(rounds.ends == [12, 17])
        #expect(rounds.goal == 17)
        // Reviews that don't divide the step: 7 reviews take 70 s, the 2nd new card reaches 120 s at 70 + 30 + 30 = 130.
        let uneven = DayRounds(otherCards: 7, newCards: 6, pace: pace, seconds: 360)
        #expect(uneven.ends == [9, 13])
        #expect(uneven.goal == 13)
    }

    @Test func theGoalIsTheCardsThatFitTheSecondsAndMoreReviewsThanTheTimeStayInThePlanOnly() {
        // 240 s hold 24 reviews of 10 s: the goal is those, the plan has 100.
        let rounds = DayRounds(otherCards: 100, newCards: 0, pace: pace, seconds: 240)
        #expect(rounds.goal == 24)
        #expect(rounds.ends == [12, 24])
        // New cards are admitted after the reviews only: none fit behind a full day of them.
        #expect(DayRounds(otherCards: 100, newCards: 10, pace: pace, seconds: 240).goal == 24)
    }

    @Test func theSecondsAreNotRoundedIntoSteps() {
        #expect(DayRounds(otherCards: 100, newCards: 0, pace: pace, seconds: 250).goal == 25)
        #expect(DayRounds(otherCards: 0, newCards: 10, pace: pace, seconds: 269).goal == 8)
        #expect(DayRounds(otherCards: 0, newCards: 10, pace: pace, seconds: 270).goal == 9)
        #expect(DailyGoal.newCardsAllowed(seconds: 269, otherCards: 0, pace: pace) == 8)
    }

    @Test func aPlanThatDoesNotFillItsTimeEndsAtItself() {
        let rounds = DayRounds(otherCards: 5, newCards: 0, pace: pace, seconds: 480)
        #expect(rounds.ends == [5])
        #expect(rounds.rounds == 1)
    }

    @Test func aCardThatCostsMoreThanTheStreakStepIsItsEndAndATinyPlanHasAGoalOfOne() {
        let slow = Pace(newCard: 300, otherCard: 10)
        let rounds = DayRounds(otherCards: 0, newCards: 3, pace: slow, seconds: 240)
        // One card takes 300 s and fills the day: the goal is that one card, and it is the streak step too.
        #expect(rounds.goal == 1)
        #expect(rounds.ends == [1])
        // Within a longer day the first card ends the streak step and two cards fill the 600 s.
        #expect(DayRounds(otherCards: 0, newCards: 3, pace: slow, seconds: 600).ends == [1, 2])
        // The plan has a card, so the goal is at least one even when it costs more than the whole day.
        #expect(DayRounds(otherCards: 0, newCards: 3, pace: Pace(newCard: 900, otherCard: 10), seconds: 120).goal == 1)
    }

    @Test func aPlanWithoutCardsHasNoEnds() {
        let rounds = DayRounds(otherCards: 0, newCards: 0, pace: pace, seconds: 360)
        #expect(rounds.ends.isEmpty)
        #expect(rounds.goal == 0)
        #expect(rounds.rounds == 0)
        #expect(rounds.cardsToNextRound(cardsDone: 0) == nil)
        #expect(rounds.minutesToNextRound(cardsDone: 0) == nil)
    }

    @Test func theEndsDoneAndTheWayToTheNextOneFollowTheCardsDone() {
        let rounds = DayRounds(otherCards: 12, newCards: 5, pace: pace, seconds: 360)
        #expect(rounds.roundsDone(cardsDone: 0) == 0)
        #expect(rounds.roundsDone(cardsDone: 11) == 0)
        #expect(rounds.roundsDone(cardsDone: 12) == 1)
        #expect(rounds.roundsDone(cardsDone: 16) == 1)
        #expect(rounds.roundsDone(cardsDone: 17) == 2)
        #expect(rounds.roundsDone(cardsDone: 60) == 2)
        #expect(rounds.cardsToNextRound(cardsDone: 0) == 12)
        #expect(rounds.cardsToNextRound(cardsDone: 5) == 7)
        #expect(rounds.cardsToNextRound(cardsDone: 12) == 5)
        #expect(rounds.cardsToNextRound(cardsDone: 17) == nil)
        // 12 reviews at 10 s are 2 minutes; from 6 done, 60 s are left, one minute.
        #expect(rounds.minutesToNextRound(cardsDone: 0) == 2)
        #expect(rounds.minutesToNextRound(cardsDone: 6) == 1)
        #expect(rounds.minutesToNextRound(cardsDone: 11) == 0)
        // Five new cards at 30 s are 150 s: three minutes up.
        #expect(rounds.minutesToNextRound(cardsDone: 12) == 3)
        #expect(rounds.minutesToNextRound(cardsDone: 17) == nil)
    }

    @Test func eachStretchHasItsMinutesAtTheDaysPace() {
        // 12 reviews at 10 s are 2 minutes; the five new cards at 30 s are 150 s, three minutes up.
        let rounds = DayRounds(otherCards: 12, newCards: 5, pace: pace, seconds: 360)
        #expect(rounds.ends == [12, 17])
        #expect(rounds.minutes(ofRound: 1) == 2)
        #expect(rounds.minutes(ofRound: 2) == 3)
        #expect(rounds.minutes(ofRound: 0) == nil)
        #expect(rounds.minutes(ofRound: 3) == nil)
        #expect(DayRounds(otherCards: 0, newCards: 0, pace: pace, seconds: 240).minutes(ofRound: 1) == nil)
    }

    @Test func aPriceBelowASecondIsASecond() {
        #expect(Pace(newCard: 0, otherCard: -3) == Pace(newCard: 1, otherCard: 1))
        #expect(DayRounds(otherCards: 3, newCards: 3, pace: Pace(newCard: 0, otherCard: 0), seconds: 120).goal == 6)
    }
}
