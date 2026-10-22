import Foundation
import Testing

@testable import VocabCore

/// The part of a card a day's answers made (`Card.credit`): every answer recalled moves it, Forgot
/// doesn't, and nothing is taken back.
struct CardCreditTests {
    let calendar = StudyCalendar.testing
    /// 2026-10-05 18:00 in Berlin.
    let now = Date(timeIntervalSince1970: 1_791_216_000)

    func card(_ grades: [Grade], daysBefore: [Grade] = []) -> Card {
        var options = LearningOptions()
        options.fuzzing = false
        let today = calendar.start(ofDay: calendar.dayNumber(for: now)).addingTimeInterval(10 * 3600)
        let earlier = today.addingTimeInterval(-10 * 86400)
        let log =
            daysBefore.enumerated().map { ReviewLogEntry(date: earlier.addingTimeInterval(Double($0.offset) * 60), grade: $0.element) }
            + grades.enumerated().map { ReviewLogEntry(date: today.addingTimeInterval(Double($0.offset) * 60), grade: $0.element) }
        return Scheduler(learningOptions: options, calendar: calendar).replaying(log, of: Card(question: "λέξη", answer: "word"))
    }

    func credit(_ card: Card) -> Double { card.credit(onDayOf: now, calendar: calendar, steps: 2) }

    @Test func aNewCardMovesWithEveryAnswerRecalled() {
        #expect(credit(card([])) == 0)
        #expect(credit(card([.good])) == 0.5)
        #expect(credit(card([.good, .good])) == 1)
        #expect(credit(card([.easy])) == 1)
        #expect(credit(card([.hard])) == 1.0 / 3)
        #expect(credit(card([.hard, .good])) == 2.0 / 3)
        #expect(credit(card([.again])) == 0)
    }

    @Test func forgotTakesNothingBack() {
        #expect(credit(card([.good, .again])) == 0.5)
        // Two answers recalled, one step to go.
        #expect(credit(card([.good, .again, .good])) == 2.0 / 3)
        #expect(credit(card([.good, .again, .good, .good])) == 1)
    }

    @Test func aReviewCardIsDoneWhenRecalledAndRelearnsAfterForgot() {
        let learned: [Grade] = [.good, .good]
        #expect(credit(card([.good], daysBefore: learned)) == 1)
        #expect(credit(card([.again], daysBefore: learned)) == 0)
        #expect(credit(card([.again, .good], daysBefore: learned)) == 0.5)
    }

    @Test func theRingShowsTheCardsUnderway() throws {
        var options = LearningOptions()
        options.fuzzing = false
        let deck = try Deck(learningOptions: options, cards: [card([.good]), card([.good, .good]), card([.again])])
        #expect(deck.doneCards(onDayOf: now, calendar: calendar) == 1)
        #expect(deck.cardsUnderway(onDayOf: now, calendar: calendar) == 0.5)
        #expect(DailyRing(done: 1, goal: 3, underway: 0.5).fraction == 0.5)
    }
}
