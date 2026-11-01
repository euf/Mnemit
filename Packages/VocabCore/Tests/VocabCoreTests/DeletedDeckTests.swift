import Foundation
import Testing

@testable import VocabCore

/// A deleted deck's reviews outlive it (`Deck.retired`): today keeps the cards done in it, the streak step and the words
/// right, and no day plans it.
struct DeletedDeckTests {
    let calendar = StudyCalendar.testing
    let today = StudyCalendar.testing.dayNumber(for: Date(timeIntervalSince1970: 1_791_216_000))

    func noon(_ day: Int) -> Date { calendar.start(ofDay: day).addingTimeInterval(8 * 3600) }

    /// A card answered Good at noon of each of `days`.
    func card(_ question: String, _ days: [Int], id: UUID = UUID()) -> Card {
        var card = Card(id: id, question: question, answer: "a", note: nil, created: noon(today - 30), learningState: nil)
        card.log = days.map { ReviewLogEntry(date: noon($0), grade: .good, mode: .revealed, duration: .seconds(6)) }
        return card
    }

    /// A card learned two days ago (two Goods, the default steps) and answered Good today: one of today's done cards.
    func doneToday(_ question: String) -> Card {
        let scheduler = Scheduler(learningOptions: LearningOptions(), calendar: calendar)
        var random = SeededRandom(seed: 1)
        var card = Card(question: question, answer: "a", note: nil, created: noon(today - 30), learningState: nil)
        for date in [noon(today - 2), noon(today - 2).addingTimeInterval(600), noon(today)] {
            card = scheduler.review(card, grade: .good, at: date, using: &random)
        }
        return card
    }

    func evaluate(_ decks: [Deck]) -> DailyProgress {
        DailyProgress.evaluate(decks.map { DeckActivity(deck: $0, calendar: calendar) }, at: noon(today), calendar: calendar)
    }

    @Test func aRetiredDeckKeepsItsReviewsAndAsksForNothing() throws {
        let deck = try Deck(cards: [card("studied", [today - 1, today]), card("never studied", [])])
        let retired = deck.retired()
        #expect(retired.cards.isEmpty)
        #expect(retired.retiredCards.map(\.question) == ["studied"])
        #expect(retired.learningOptions.isPaused)
        #expect(deck.retired(excluding: [deck.cards[0].id]).retiredCards.isEmpty)
    }

    @Test func todayKeepsTheWorkOfADeckDeletedToday() throws {
        let kept = try Deck(cards: (0..<4).map { doneToday("kept \($0)") })
        let deleted = try Deck(cards: (0..<6).map { doneToday("deleted \($0)") })
        let before = evaluate([kept, deleted])
        let after = evaluate([kept] + Deck.retired([deleted], excluding: Set(kept.cards.map(\.id))))
        #expect(before.ring.done == 10)
        #expect(after.ring.done == before.ring.done)
        #expect(after.wordsRight == before.wordsRight)
        #expect(after.streakKeptToday == before.streakKeptToday)
        #expect(after.cardsLeft <= before.cardsLeft)
        // The control: without its copy the deck's work is gone from today.
        #expect(evaluate([kept]).ring.done < before.ring.done)
        #expect(evaluate([kept]).wordsRight.words < before.wordsRight.words)
    }

    @Test func aDeckDeletedTwiceCountsOnceAndADeckTakenBackCountsInItself() throws {
        let first = try Deck(cards: [card("a", [today - 3]), card("b", [today - 3])])
        // Taken out of the Trash, studied again and deleted again: the newer copy holds both cards with more reviews.
        let second = try Deck(cards: [card("a", [today - 3, today], id: first.cards[0].id), card("b", [today - 3, today], id: first.cards[1].id)])
        let retired = Deck.retired([second, first], excluding: [])
        #expect(retired.count == 1)
        #expect(retired[0].retiredCards.map(\.log.count) == [2, 2])
        // A deck back in the folder holds its cards: no copy counts them.
        #expect(Deck.retired([second, first], excluding: Set(first.cards.map(\.id))).isEmpty)
    }
}
