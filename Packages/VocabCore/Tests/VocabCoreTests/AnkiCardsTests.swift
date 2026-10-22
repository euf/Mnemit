import Foundation
import Testing

@testable import VocabCore

/// Cards made of the notes of `AnkiImport`: their learning state comes from replaying the reviews.
struct AnkiCardsTests {
    let calendar = StudyCalendar.testing
    let created = Date(timeIntervalSince1970: 1_791_216_000)
    let options = LearningOptions()

    /// 5:00 on study day `offset` of an arbitrary start, in whole seconds.
    func time(day offset: Int, minutes: Int = 0) -> Date {
        calendar.start(ofDay: 20_000 + offset).addingTimeInterval(3600 + Double(minutes) * 60)
    }

    func review(_ grade: Grade, day: Int, minutes: Int = 0) -> ReviewLogEntry {
        ReviewLogEntry(date: time(day: day, minutes: minutes), grade: grade, mode: .revealed)
    }

    func cards(_ notes: [AnkiImport.Note], options: LearningOptions? = nil) -> [Card] {
        AnkiImport.cards(from: notes, learningOptions: options ?? self.options, calendar: calendar, created: created)
    }

    var history: [ReviewLogEntry] {
        [review(.good, day: 0), review(.good, day: 0, minutes: 10), review(.good, day: 1), review(.again, day: 10), review(.easy, day: 10, minutes: 5)]
    }

    @Test func aNoteWithoutReviewsIsANewCard() throws {
        let card = try #require(cards([.init(front: "γάτα", back: "cat")]).first)
        #expect(card.question == "γάτα" && card.answer == "cat" && card.hint == "")
        #expect(card.isNew && card.log.isEmpty && !card.isSuspended)
        #expect(card.created == created)
        #expect(card.note == nil && card.kind == nil)
    }

    @Test func replaysTheReviewsThroughTheScheduler() throws {
        let card = try #require(cards([.init(front: "γάτα", back: "cat", reviews: history)]).first)
        let state = try #require(card.learningState)

        // The same steps as studying the card here: every review through `Scheduler.review`.
        let scheduler = Scheduler(learningOptions: options, calendar: calendar)
        var expected = Card(id: card.id, question: "γάτα", answer: "cat", created: created, learningState: nil)
        for entry in history {
            var random = Scheduler.random(forReviewOf: card.id, at: entry.date)
            expected = scheduler.review(expected, grade: entry.grade, at: entry.date, mode: entry.mode, using: &random)
        }
        #expect(card.learningState == expected.learningState)
        #expect(card == expected)

        #expect(card.log == history)
        #expect(card.hasCompleteLog)
        #expect(state.reviews == 5)
        #expect(state.lapses == 1)
        #expect(state.lastReview == time(day: 10, minutes: 5))
        // Easy after the lapse is a graduation at once, so the card is back in review.
        #expect(state.phase == .review)
        #expect(state.due > state.lastReview)
        #expect(state.stability > 0)
    }

    @Test func theDecksOptionsDecideTheState() throws {
        let notes = [AnkiImport.Note(front: "a", back: "b", reviews: Array(history.prefix(3)))]
        var oneStep = options
        oneStep.steps = 1
        var demanding = options
        demanding.targetRecall = 0.97
        var lenient = options
        lenient.targetRecall = 0.8
        var unfuzzed = options
        unfuzzed.fuzzing = false

        let normal = try #require(cards(notes).first?.learningState)
        #expect(try #require(cards(notes, options: oneStep).first?.learningState).reviews == 3)
        // With two steps the first two good reviews have graduated the card; with one, the first.
        #expect(try #require(cards([.init(front: "a", back: "b", reviews: [review(.good, day: 0)])], options: oneStep).first?.learningState).phase == .review)
        #expect(try #require(cards([.init(front: "a", back: "b", reviews: [review(.good, day: 0)])]).first?.learningState).phase == .learning)

        let demandingDue = try #require(cards(notes, options: demanding).first?.learningState).due
        let lenientDue = try #require(cards(notes, options: lenient).first?.learningState).due
        #expect(demandingDue < normal.due && normal.due < lenientDue)
        // Fuzz moves an interval by a few percent only.
        let exact = try #require(cards(notes, options: unfuzzed).first?.learningState)
        #expect(abs(exact.due.timeIntervalSince(normal.due)) < 4 * 86_400)
        #expect(exact.stability == normal.stability)
    }

    @Test func aSuspendedNoteIsASuspendedCardThatKeepsItsHistory() throws {
        let card = try #require(cards([.init(front: "a", back: "b", reviews: history, isSuspended: true)]).first)
        #expect(card.isSuspended)
        #expect(card.suspensionChanged == created)
        #expect(card.learningState?.reviews == 5)
        #expect(!card.isDue(at: .distantFuture))
    }

    @Test func skipsNotesWithoutTextAndGivesEveryCardItsOwnID() {
        let result = cards([
            .init(front: "a", back: "b"), .init(front: "  ", back: "b"), .init(front: "a", back: ""), .init(front: "a", back: "b"),
        ])
        #expect(result.count == 2)
        #expect(Set(result.map(\.id)).count == 2)
        #expect(cards([]).isEmpty)
    }

    @Test func theNotesOfAPackageMakeCardsInOrder() throws {
        let url = try #require(Bundle.module.url(forResource: "Resources/Anki/greek-latest", withExtension: "apkg"))
        let result = try AnkiImport.read(url)
        let made = result.cards(learningOptions: options, calendar: calendar, created: created)
        #expect(made.map(\.question) == ["γάτα", "σπίτι\nτο", "ήχος", "νερό", "water", "σκύλος"])
        #expect(made.map(\.isNew) == [false, false, true, false, false, true])
        #expect(made.map(\.isSuspended) == [false, false, false, false, false, true])
        #expect(made[0].log.count == 5 && made[0].learningState?.lapses == 1)
    }

    @Test func importedCardsJoinADeckAndSurviveSaving() throws {
        var deck = Deck()
        let made = cards([.init(front: "a", back: "b", reviews: history), .init(front: "c", back: "d"), .init(front: "e", back: "f", reviews: [review(.good, day: 0)], isSuspended: true)])
        let change = try #require(DeckChange.importing(made, into: deck))
        _ = deck.apply(change, at: time(day: 11), calendar: calendar)
        #expect(deck.cards == made)
        #expect(deck.cards[0].learningState?.reviews == 5)
        #expect(deck.dueCount(at: .distantFuture) == 2)

        // Written and read again, as `deck.json` and `reviews.jsonl`.
        #expect(try DeckFile.decode(DeckFile.fileWrapper(for: deck)) == deck)

        // Nothing is added twice, and `adding` still takes new cards only.
        #expect(DeckChange.importing(made, into: deck) == nil)
        #expect(DeckChange.importing([], into: deck) == nil)
        #expect(DeckChange.adding(made, to: Deck())?.upserts.count == 1)
    }

    @Test func theSettingsOfThePresetChangeTheReplayedCards() throws {
        let url = try #require(Bundle.module.url(forResource: "Resources/Anki/greek-latest", withExtension: "apkg"))
        let result = try AnkiImport.read(url)
        let preset = try #require(result.learningOptions(applyingTo: options))
        let plain = result.cards(learningOptions: options, calendar: calendar, created: created)
        let tuned = result.cards(learningOptions: preset, calendar: calendar, created: created)
        // The cat has history: the parameters give it another stability and difficulty than the defaults do.
        let before = try #require(plain[0].learningState)
        let after = try #require(tuned[0].learningState)
        #expect(after.stability != before.stability)
        #expect(after.difficulty != before.difficulty)
        #expect(plain[2].isNew && tuned[2].isNew)
    }

    @Test func aNewDeckTakesTheOptionsInTheSameChange() throws {
        let preset = AnkiPreset(name: "a", parameters: FSRSParameters.default.weights.map { Float($0) }, desiredRetention: 0.85)
        let applied = try #require(preset.learningOptions(applyingTo: options))
        var deck = Deck()
        let made = cards([.init(front: "a", back: "b", reviews: history)], options: applied)
        let change = try #require(DeckChange.importing(made, into: deck, learningOptions: applied))
        let inverse = deck.apply(change, at: time(day: 11), calendar: calendar)
        #expect(deck.learningOptions == applied && deck.cards == made)
        #expect(deck.learningOptionsChanged != nil)
        // One undo takes the cards and the options back.
        _ = deck.apply(inverse, at: time(day: 11), calendar: calendar)
        #expect(deck.cards.isEmpty && deck.learningOptions == options)

        // Options that are the deck's already, or none, leave them (and their stamp) alone.
        var plain = Deck()
        let same = try #require(DeckChange.importing(made, into: plain, learningOptions: options))
        _ = plain.apply(same, at: time(day: 11), calendar: calendar)
        #expect(plain.learningOptionsChanged == nil)
    }
}
