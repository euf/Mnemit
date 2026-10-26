import Foundation
import Testing

@testable import VocTrain
@testable import VocabCore

/// A deck that introduces new words (`LearningOptions.introducesNewCards`): the stream shows a new card first as a
/// new word, with its answer open, and moves on without a grade; the core's `IntroductionTests` have the rules,
/// these have what the shared model and driver make of them for the two apps.
@MainActor
struct StudyIntroductionTests {
    let created = Date(timeIntervalSince1970: 1_791_216_000)

    /// Two never-seen words and, with `review`, one card that is due.
    func makeDocument(new: Int = 2, review: Bool = false, introducing: Bool = true) throws -> (VocabularyDocument, UndoManager) {
        var options = LearningOptions()
        options.introducesNewCards = introducing
        options.fuzzing = false
        var cards = (0..<new).map { Card(text: CardText(question: "new \($0)", answer: "a\($0)")!, created: created) }
        if review {
            let lastReview = created.addingTimeInterval(-10 * 86400)
            let state = LearningState(phase: .review, stability: 10, difficulty: 5, lastReview: lastReview, due: created.addingTimeInterval(-86400), reviews: 1)
            cards.insert(
                Card(question: "due", answer: "x", created: created, learningState: state, log: [ReviewLogEntry(date: lastReview, grade: .good, mode: .revealed)]),
                at: 0)
        }
        let document = try VocabularyDocument(deck: Deck(learningOptions: options, cards: cards), clock: StudyClock { [created] in created.addingTimeInterval(60) })
        let undoManager = UndoManager()
        undoManager.groupsByEvent = false
        document.attachUndoManager(undoManager)
        return (document, undoManager)
    }

    func grade(_ model: StudyModel, _ grade: Grade, undoManager: UndoManager) {
        undoManager.beginUndoGrouping()
        model.grade(grade)
        undoManager.endUndoGrouping()
    }

    @Test func aNewCardComesAsANewWordWithItsAnswerOpen() throws {
        let (document, undoManager) = try makeDocument()
        let model = StudyModel(document: document)
        #expect(model.isIntroduction)
        #expect(model.stage == .revealed)

        // No grade for a word that is only shown.
        grade(model, .good, undoManager: undoManager)
        #expect(model.session.reviewCount == 0)
        #expect(model.isIntroduction)
        #expect(document.deck.cards.allSatisfy { $0.isNew && $0.log.isEmpty })
    }

    @Test func introducingMovesOnWithoutAStepOrAChange() throws {
        let (document, _) = try makeDocument()
        let model = StudyModel(document: document)
        let first = try #require(model.currentCard?.id)
        let number = model.questionNumber

        model.introduce()
        #expect(model.questionNumber == number + 1)
        #expect(model.currentCard?.id != first)
        #expect(model.isIntroduction)
        #expect(!model.hasUndoableSteps)
        #expect(!model.canUndo)
        #expect(model.lastReceipt == nil)
        #expect(document.deck.cards.allSatisfy { $0.isNew && $0.log.isEmpty })
        #expect(model.session.completedCount == 0)
    }

    @Test func theWordsAreAskedAsQuestionsAfterTheirIntroduction() throws {
        let (document, undoManager) = try makeDocument()
        let model = StudyModel(document: document)
        model.introduce()
        model.introduce()
        // Nothing else is left: the first word comes back at once, as a question.
        #expect(!model.isIntroduction)
        #expect(model.stage == .asking)
        let asked = try #require(model.currentCard)

        model.reveal()
        grade(model, .good, undoManager: undoManager)
        #expect(document.card(withID: asked.id)?.learningState != nil)
        #expect(document.card(withID: asked.id)?.log.map(\.grade) == [.good])
        #expect(model.hasUndoableSteps)
    }

    @Test func aDeckThatKnowsItsWordsAsksNewCardsAsBefore() throws {
        let (document, _) = try makeDocument(introducing: false)
        let model = StudyModel(document: document)
        #expect(!model.isIntroduction)
        #expect(model.stage == .asking)
    }

    @Test func undoAfterAnIntroductionGoesBackToTheLastGradedCard() throws {
        // The stream picks its first card at random from the front of the rotation; this test needs the review first.
        var made: (VocabularyDocument, UndoManager, StudyModel)?
        for _ in 0..<64 where made == nil {
            let (document, undoManager) = try makeDocument(new: 1, review: true)
            let model = StudyModel(document: document)
            if model.currentCard?.question == "due" { made = (document, undoManager, model) }
        }
        let (document, undoManager, model) = try #require(made)
        let due = try #require(model.currentCard)
        #expect(!model.isIntroduction)

        model.reveal()
        grade(model, .good, undoManager: undoManager)
        #expect(model.isIntroduction)
        #expect(model.canUndo)

        model.introduce()
        // The introduction is no step: Undo still takes back the review before it.
        #expect(model.canUndo)
        model.undoLast()
        #expect(model.currentCard?.id == due.id)
        #expect(model.stage == .revealed)
        #expect(!model.isIntroduction)
        #expect(document.deck.cards.filter(\.isNew).count == 1)

        undoManager.redo()
        #expect(model.isIntroduction)
        #expect(model.currentCard?.question == "new 0")
    }

    @Test func practicesNeverIntroduce() throws {
        let (document, _) = try makeDocument()
        let model = StudyModel(document: document, entry: .practiceNewest)
        #expect(!model.isIntroduction)
        #expect(model.stage == .asking)
    }

    @Test func theNewWordChipSaysSoOnlyWhileItIsIntroduced() throws {
        let (document, _) = try makeDocument()
        let model = StudyModel(document: document)
        let card = try #require(model.currentCard)
        let memory = CardMemory(
            card: card, in: document.deck, at: document.clock.now, calendar: document.calendar, isIntroduction: model.isIntroduction)
        #expect(memory.isIntroduction)
        #expect(memory.step == .new)
        #expect(!CardMemory(card: card, in: document.deck, at: document.clock.now, calendar: document.calendar).isIntroduction)
    }

    /// The time on screen while a word is introduced counts for the first review of the card: the driver logs it.
    @Test func theIntroductionsTimeIsInTheFirstReviewsDuration() throws {
        let (document, undoManager) = try makeDocument(new: 1)
        let clock = SessionDriverDurationTests.TestClock()
        let stream = StudyStream(deck: document.deck, at: document.clock.now, calendar: document.calendar, reviewMode: .revealed)
        let driver = SessionDriver(document: document, stream: stream, now: clock.now)
        let id = try #require(driver.currentCard?.id)
        #expect(driver.session.isIntroduction)

        clock.advance(.milliseconds(2000))
        driver.introduceCurrentCard()
        #expect(document.card(withID: id)?.log == [])
        // The only card comes back at once, as a question.
        #expect(driver.currentCard?.id == id)
        #expect(!driver.session.isIntroduction)

        clock.advance(.milliseconds(1500))
        undoManager.beginUndoGrouping()
        driver.grade(.good)
        undoManager.endUndoGrouping()
        #expect(document.card(withID: id)?.log.map(\.duration) == [.milliseconds(3500)])
    }
}
