import Foundation

@testable import VocabCore

/// A deck with a history of study, for the tests that need hundreds of days of log.
enum StudiedDeck {
    /// A learner who studies the plan of 85 % of the `days` before the day it returns, grading Good, Hard or
    /// Again as a person does, on `cards` cards, half of them recognition cards and half the production cards
    /// of the same words. The day is the one after the last study day, mid-afternoon.
    static func make(cards: Int, days: Int, calendar: StudyCalendar = .testing) throws -> (deck: Deck, now: Date) {
        var options = LearningOptions()
        options.cardsPerSession = nil
        options.newCardsPerSession = 12
        options.newProductionPerSession = 6
        let end = calendar.start(ofDay: CivilDate(year: 2026, month: 10, day: 5).dayNumber)
        let firstDay = calendar.dayNumber(for: end) - days
        var deck = try Deck(
            learningOptions: options,
            cards: (0..<cards).map { index in
                Card(
                    text: CardText(question: "q\(index)", answer: "a\(index)", hint: "")!, note: "n\(index / 2)", kind: index.isMultiple(of: 2) ? .recognition : .production,
                    created: calendar.start(ofDay: firstDay - 1))
            })
        var random = SeededRandom(seed: 5)
        for day in firstDay..<(firstDay + days) {
            guard random.next() % 100 < 85 else { continue }
            let at = calendar.start(ofDay: day).addingTimeInterval(10 * 3600)
            var study = StudySession(deck: deck, at: at, calendar: calendar, random: SeededRandom(seed: UInt64(day)), reviewMode: .revealed)
            var clock = at
            var count = 0
            while let id = study.session.currentCardID, count < 400 {
                let roll = random.next() % 100
                let grade: Grade = roll < 82 ? .good : roll < 92 ? .hard : .again
                clock = clock.addingTimeInterval(8)
                let card = study.review(grade, of: deck.card(withID: id)!, with: options, at: clock, calendar: calendar, duration: .seconds(6))!
                deck.cards[deck.index(of: id)!] = card
                count += 1
            }
        }
        return (deck, end.addingTimeInterval(14 * 3600))
    }
}
