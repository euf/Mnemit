import Foundation
import Testing

@testable import VocabCore

/// The day's time and where it ends: the streak step and the goal in cards, and how many new cards the time admits.
struct DailyRoundsTests {
    /// A learner whose new card takes 30 s and any other 10 s.
    let pace = Pace(newCard: 30, otherCard: 10)

    // MARK: Time

    @Test func theStreakStepIsTwoMinutesAndTheFirstDayHoldsTwoAndAHalf() {
        #expect(DailyGoal.streakSeconds == 120)
        #expect(DailyGoal.initialSeconds == 150)
        #expect(DailyGoal.timeRange == 120...3600)
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

    private typealias Queue = DailyGoal.NewQueue
    private let queueStart = Date(timeIntervalSince1970: 1_791_216_000)

    private func word(_ day: Int, _ minutes: Double = 0) -> Queue.Entry { .word(day: day, created: queueStart.addingTimeInterval(minutes * 60)) }
    private func unlocked(_ daysAgo: Double) -> Queue.Entry { .unlocked(learned: queueStart.addingTimeInterval(-daysAgo * 86400)) }

    @Test func theAllowanceIsOneQueueOfTheNewestWordsAcrossTheDecks() {
        // The words go by the study day of their addition, the later first, whichever deck they are in.
        let a = Queue(entries: [word(10, 0), word(9, 0), word(1, 0)])
        let b = Queue(entries: [word(10, 5), word(8, 0)])
        #expect(DailyGoal.split(1, overQueues: [a, b]) == [1, 0])
        #expect(DailyGoal.split(2, overQueues: [a, b]) == [1, 1])
        #expect(DailyGoal.split(3, overQueues: [a, b]) == [2, 1])
        #expect(DailyGoal.split(4, overQueues: [a, b]) == [2, 2])
        #expect(DailyGoal.split(5, overQueues: [a, b]) == [3, 2])
        #expect(DailyGoal.split(0, overQueues: [a, b]) == [0, 0])
    }

    @Test func wordsOfOneDayGoByTheirAdditionThenByTheEarlierDeckThenByPlace() {
        let a = Queue(entries: [word(10, 30), word(10, 30)])
        let b = Queue(entries: [word(10, 30), word(10, 10)])
        // b's second word was added first, then come the three added together: a, a, b.
        #expect(DailyGoal.split(1, overQueues: [a, b]) == [0, 1])
        #expect(DailyGoal.split(2, overQueues: [a, b]) == [1, 1])
        #expect(DailyGoal.split(3, overQueues: [a, b]) == [2, 1])
        // Reversed, the earlier deck of the two still takes the tie.
        #expect(DailyGoal.split(3, overQueues: [b, a]) == [2, 1])
    }

    @Test func openedProductionCardsAlternateWithTheWordsOldestLearnedFirstAcrossTheDecks() {
        // Words, newest first: a, a, a. Opened cards, oldest learned first: b (30 days), a (12), b (5).
        let a = Queue(entries: [word(10), word(9), word(8), unlocked(12)])
        let b = Queue(entries: [unlocked(5), unlocked(30)])
        #expect(DailyGoal.split(1, overQueues: [a, b]) == [1, 0])
        // The word first, then the oldest opened card, which is b's.
        #expect(DailyGoal.split(2, overQueues: [a, b]) == [1, 1])
        #expect(DailyGoal.split(3, overQueues: [a, b]) == [2, 1])
        #expect(DailyGoal.split(4, overQueues: [a, b]) == [3, 1])
        // The last word, then b's newest learned card.
        #expect(DailyGoal.split(5, overQueues: [a, b]) == [4, 1])
        #expect(DailyGoal.split(6, overQueues: [a, b]) == [4, 2])
        #expect(DailyGoal.split(9, overQueues: [a, b]) == [4, 2])
        // The longer list goes on alone after the shorter: one word, three opened cards (a's two, then b's).
        let few = [Queue(entries: [word(3), unlocked(9), unlocked(8)]), Queue(entries: [unlocked(7)])]
        #expect(DailyGoal.split(2, overQueues: few) == [2, 0])
        #expect(DailyGoal.split(3, overQueues: few) == [3, 0])
        #expect(DailyGoal.split(4, overQueues: few) == [3, 1])
    }

    @Test func aDeckWithNewCardsPerDayKeepsAllItsQueueOutsideTheTotal() {
        let limited = Queue(entries: [word(10), word(9), unlocked(3), unlocked(2)], isLimited: true)
        let open = Queue(entries: [word(8), word(7), word(6)])
        #expect(DailyGoal.split(0, overQueues: [limited, open]) == [4, 0])
        // The limited deck's cards, though newer than the open deck's, don't take the total's places.
        #expect(DailyGoal.split(2, overQueues: [limited, open]) == [4, 2])
        #expect(DailyGoal.split(100, overQueues: [limited, open]) == [4, 3])
        #expect(DailyGoal.split(2, overQueues: [open, limited]) == [2, 4])
        #expect(DailyGoal.split(2, overQueues: [limited]) == [4])
    }

    @Test func noDeckGetsMoreThanItsQueueAndATotalBeyondTheirSumLeavesThemWhole() {
        let queues = [Queue(entries: Array(repeating: word(5), count: 7)), Queue(entries: [unlocked(1), unlocked(2), unlocked(3)]), Queue()]
        #expect(DailyGoal.split(100, overQueues: queues) == [7, 3, 0])
        #expect(DailyGoal.split(10, overQueues: queues) == [7, 3, 0])
        #expect(DailyGoal.split(9, overQueues: queues) == [6, 3, 0])
        #expect(DailyGoal.split(5, overQueues: []) == [])
        #expect(DailyGoal.split(-3, overQueues: queues) == [0, 0, 0])
    }

    @Test func theSplitAddsUpToTheTotalWhenTheQueuesAreEnoughForIt() {
        let queues = [
            Queue(entries: (0..<10).map { word($0 % 4, Double($0)) }),
            Queue(entries: (0..<6).map { unlocked(Double($0)) } + (0..<4).map { word(2, Double($0)) }),
            Queue(entries: (0..<5).map { word(9, Double($0)) }, isLimited: true),
        ]
        for total in 0...40 {
            let parts = DailyGoal.split(total, overQueues: queues)
            // The limited deck's 5 are outside the total; the other two hold 20.
            #expect(parts[2] == 5)
            #expect(parts[0] + parts[1] == min(total, 20))
            #expect(zip(parts, queues).allSatisfy { $0 <= $1.entries.count })
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

    @Test func aBacklogOfFifteenHundredWithASixMinuteDayHasTheGoalThatFitsAndNoSpread() {
        // 360 s hold 36 reviews of 10 s: the goal is those, however many are overdue; the other 1464 stay in the plan.
        let rounds = DayRounds(otherCards: 1500, newCards: 0, pace: pace, seconds: 360)
        #expect(rounds.goal == 36)
        #expect(rounds.ends == [12, 36])
        #expect(DayRounds(otherCards: 1500, newCards: 20, pace: pace, seconds: 360).goal == 36)
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
