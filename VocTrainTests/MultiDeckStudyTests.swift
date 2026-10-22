import Foundation
import Testing

@testable import VocTrain
@testable import VocabCore

/// One stream over several decks: each card comes from the deck whose next card is most urgent, the
/// grade goes to that deck, and Undo goes back across decks.
@MainActor
struct MultiDeckStudyTests {
    let created = Date(timeIntervalSince1970: 1_791_216_000)
    /// The documents hold their undo managers weakly: the test keeps them.
    private let undoManagers = UndoManagers()

    final class UndoManagers {
        var all: [UndoManager] = []
    }

    private func document(_ cards: [Card]) throws -> VocabularyDocument {
        let document = try VocabularyDocument(deck: Deck(cards: cards), clock: StudyClock { [created] in created.addingTimeInterval(60) })
        let undoManager = UndoManager()
        undoManager.groupsByEvent = false
        document.attachUndoManager(undoManager)
        undoManagers.all.append(undoManager)
        return document
    }

    private func newCards(_ questions: [String]) -> [Card] {
        questions.map { Card(text: CardText(question: $0, answer: "x")!, created: created) }
    }

    private func dueReviews(_ questions: [String]) -> [Card] {
        let calendar = StudyCalendar()
        let dueToday = calendar.start(ofDay: calendar.dayNumber(for: created.addingTimeInterval(60)))
        let lastReview = dueToday.addingTimeInterval(-10 * 86400)
        return questions.map { question in
            let state = LearningState(phase: .review, stability: 10, difficulty: 5, lastReview: lastReview, due: dueToday, reviews: 1)
            return Card(question: question, answer: "x", created: created, learningState: state, log: [ReviewLogEntry(date: lastReview, grade: .good, mode: .revealed)])
        }
    }

    /// Grades the card being asked in an undo group of its deck, like one tap in the app.
    private func grade(_ model: StudyModel, _ grade: Grade) {
        let undoManager = model.document.undoManager
        model.reveal()
        undoManager?.beginUndoGrouping()
        model.grade(grade)
        undoManager?.endUndoGrouping()
    }

    @Test func aReviewDueInOneDeckComesBeforeTheNewCardsOfAnother() throws {
        let words = try document(newCards(["a", "b"]))
        let reviews = try document(dueReviews(["r"]))
        let model = StudyModel(documents: [words, reviews])
        #expect(model.document === reviews)
        #expect(model.currentCard?.question == "r")
        grade(model, .good)
        #expect(model.document === words)
        #expect(model.currentCard?.isNew == true)
        #expect(reviews.deck.cards[0].log.count == 2)
    }

    @Test func newCardsAreTakenFromTheDecksInTurn() throws {
        let first = try document(newCards(["a1", "a2", "a3"]))
        let second = try document(newCards(["b1", "b2", "b3"]))
        let model = StudyModel(documents: [first, second])
        var decks: [ObjectIdentifier] = []
        for _ in 0..<2 {
            guard model.currentCard?.isNew == true else { break }
            decks.append(ObjectIdentifier(model.document))
            grade(model, .easy)
        }
        #expect(Set(decks).count == 2)
    }

    @Test func undoGoesBackToTheDeckOfTheLastStep() throws {
        let words = try document(newCards(["a"]))
        let reviews = try document(dueReviews(["r"]))
        let model = StudyModel(documents: [words, reviews])
        grade(model, .good)  // the review, in `reviews`
        #expect(model.document === words)
        grade(model, .easy)  // the new card, in `words`
        #expect(model.canUndo)

        model.undoLast()
        #expect(model.document === words)
        #expect(model.currentCard?.question == "a")
        #expect(model.stage == .revealed)
        #expect(words.deck.cards[0].isNew)

        model.undoLast()
        #expect(model.document === reviews)
        #expect(model.currentCard?.question == "r")
        #expect(reviews.deck.cards[0].log.count == 1)
    }

    @Test func oneDeckRunsAsBefore() throws {
        let words = try document(newCards(["a", "b"]))
        let model = StudyModel(document: words)
        #expect(model.document === words)
        grade(model, .easy)
        #expect(model.document === words)
    }
}
