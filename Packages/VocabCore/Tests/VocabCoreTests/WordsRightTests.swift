import Foundation
import Testing

@testable import VocabCore

/// The words right: the different words answered right in the last 7 study days, the median seconds of their answers
/// and the best week before.
struct WordsRightTests {
    let calendar = StudyCalendar.testing
    let today = StudyCalendar.testing.dayNumber(for: Date(timeIntervalSince1970: 1_791_216_000))

    /// Noon of the study day `day`.
    func noon(_ day: Int) -> Date { calendar.start(ofDay: day).addingTimeInterval(8 * 3600) }

    /// A card answered `grades` at noon of `days`, one each, each answer taking `seconds` when given.
    func card(_ question: String, note: String? = nil, _ answers: [(day: Int, grade: Grade)], seconds: Double? = nil) -> Card {
        var card = Card(question: question, answer: "a", note: note, created: noon(today - 30), learningState: nil)
        card.log = answers.map { ReviewLogEntry(date: noon($0.day), grade: $0.grade, mode: .revealed, duration: seconds.map { .seconds($0) }) }
        return card
    }

    func evaluate(_ decks: [[Card]]) throws -> WordsRight {
        let activities = try decks.map { DeckActivity(deck: try Deck(cards: $0), calendar: calendar) }
        return DailyProgress.evaluate(activities, at: noon(today), calendar: calendar).wordsRight
    }

    @Test func aWordCountsOnceInTheLastSevenDaysIfAnyAnswerWasRight() throws {
        let right = try evaluate([
            [
                card("once", [(today, .good)]),
                card("three times", [(today - 5, .hard), (today - 2, .good), (today, .easy)]),
                card("forgot, then relearned", [(today - 1, .again), (today - 1, .good)]),
                card("only forgot", [(today, .again), (today - 3, .again)]),
                card("first day of the week", [(today - 6, .good)]),
                card("a day too early", [(today - 7, .good)]),
                card("never answered", []),
            ]
        ])
        #expect(right.words == 4)
    }

    @Test func aWordHeldTwiceIsOneWord() throws {
        // One word in two decks and twice in one; two cards without a word key are two words.
        let right = try evaluate([
            [card("η παρέα", note: "παρέα#η", [(today, .good)]), card("company", note: "παρέα#η", [(today - 1, .good)])],
            [card("η παρέα", note: "παρέα#η", [(today, .good)]), card("one", [(today, .good)]), card("two", [(today, .good)])],
        ])
        #expect(right.words == 3)
    }

    @Test func theSecondsAnAnswerAreTheMedianOfTheWeeksTimedAnswers() throws {
        let right = try evaluate([
            [
                card("a", [(today, .good), (today - 1, .again)], seconds: 2),
                card("b", [(today - 2, .good)], seconds: 6),
                card("c", [(today - 3, .good)], seconds: 8),
                card("d", [(today - 4, .good)], seconds: 4),
                card("untimed", [(today, .good)]),
                card("last month", [(today - 20, .good)], seconds: 100),
            ]
        ])
        // 2, 2, 4, 6, 8: the middle one.
        #expect(right.secondsPerAnswer == 4)
        #expect(try evaluate([[card("untimed", [(today, .good)])]]).secondsPerAnswer == nil)
    }

    @Test func theBestWeekIsTheMostWordsRightInAnySevenDaysBeforeToday() throws {
        let busyMonthAgo = (0..<5).map { card("old \($0)", [(today - 30, .good)]) }
        let lastWeek = (0..<3).map { card("new \($0)", [(today - 2, .good)]) }
        let right = try evaluate([busyMonthAgo + lastWeek])
        #expect(right.words == 3 && right.bestBefore == 5 && right.best == 5 && !right.isBestWeek)

        let better = try evaluate([busyMonthAgo + (0..<6).map { card("new \($0)", [(today, .good)]) }])
        #expect(better.words == 6 && better.bestBefore == 5 && better.isBestWeek)
        // The first week beats nothing.
        #expect(try !evaluate([lastWeek]).isBestWeek)
    }
}
