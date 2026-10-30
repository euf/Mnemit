import Testing

@testable import VocabCore

/// The streak step of a later day, priced by one price per card: the widget's forecast and the reminders.
struct StreakStepCardsTests {
    @Test func theStepIsTheFirstCardsThatFillTwoMinutes() {
        #expect(DailyGoal.streakStepCards(in: 300, secondsPerCard: 10) == 12)
        // A card that reaches the two minutes belongs to the step, as in `DayRounds`.
        #expect(DailyGoal.streakStepCards(in: 100, secondsPerCard: 50) == 3)
        #expect(DailyGoal.streakStepCards(in: 100, secondsPerCard: 200) == 1)
    }

    @Test func aShortPlanIsAllStep() {
        #expect(DailyGoal.streakStepCards(in: 5, secondsPerCard: 10) == 5)
    }

    @Test func noCardsOrNoPriceMeanNoStep() {
        #expect(DailyGoal.streakStepCards(in: 0, secondsPerCard: 10) == 0)
        #expect(DailyGoal.streakStepCards(in: 5, secondsPerCard: 0) == 0)
    }

    @Test func itAgreesWithTheRoundsTheAppCuts() {
        let pace = Pace(newCard: 10, otherCard: 10)
        let rounds = DayRounds(otherCards: 40, newCards: 0, pace: pace, seconds: 300)
        #expect(rounds.ends.first == DailyGoal.streakStepCards(in: 40, secondsPerCard: 10))
    }
}
