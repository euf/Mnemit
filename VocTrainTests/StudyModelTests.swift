import Foundation
import Testing

@testable import VocTrain
@testable import VocabCore

@MainActor
struct StudyModelTests {
    let created = Date(timeIntervalSince1970: 1_791_216_000)

    func makeDocument(questions: [String] = ["dom", "kot"]) throws -> (VocabularyDocument, UndoManager) {
        let cards = questions.map { Card(text: CardText(question: $0, answer: "x")!, created: created) }
        let document = try VocabularyDocument(deck: Deck(cards: cards), clock: StudyClock { [created] in created.addingTimeInterval(60) })
        let undoManager = UndoManager()
        undoManager.groupsByEvent = false
        document.attachUndoManager(undoManager)
        return (document, undoManager)
    }

    /// Grades in an undo group of its own, like one tap in the app.
    func grade(_ model: StudyModel, _ grade: Grade, undoManager: UndoManager) {
        undoManager.beginUndoGrouping()
        model.grade(grade)
        undoManager.endUndoGrouping()
    }

    @Test func gradingNeedsTheAnswerShown() throws {
        let (document, undoManager) = try makeDocument()
        let model = StudyModel(document: document)
        #expect(model.stage == .asking)

        grade(model, .good, undoManager: undoManager)
        #expect(model.session.reviewCount == 0)
        #expect(document.deck.cards.allSatisfy { $0.isNew })

        model.reveal()
        #expect(model.stage == .revealed)
    }

    @Test func reviewsAreRecordedAsRevealed() throws {
        let (document, undoManager) = try makeDocument()
        let model = StudyModel(document: document)
        let id = try #require(model.currentCard?.id)

        model.reveal()
        grade(model, .good, undoManager: undoManager)
        #expect(document.card(withID: id)?.log.map(\.mode) == [.revealed])
        #expect(document.card(withID: id)?.log.map(\.grade) == [.good])
        #expect(model.session.reviewCount == 1)
        #expect(model.stage == .asking)
    }

    @Test func undoTakesBackTheCardAndTheStreamsPlace() throws {
        let (document, undoManager) = try makeDocument()
        let model = StudyModel(document: document)
        let card = try #require(model.currentCard)

        model.reveal()
        grade(model, .again, undoManager: undoManager)
        undoManager.undo()
        #expect(document.card(withID: card.id) == card)
        #expect(model.currentCard == card)
        #expect(model.session.reviewCount == 0)
        #expect(model.stage == .asking)

        undoManager.redo()
        #expect(document.card(withID: card.id)?.log.map(\.grade) == [.again])
        #expect(model.session.reviewCount == 1)
    }

    /// On the iPhone too, a card can be suspended in the stream, revealed or not (#290).
    @Test func suspendingMovesOnAndCanBeUndone() throws {
        let (document, undoManager) = try makeDocument()
        let model = StudyModel(document: document)
        let card = try #require(model.currentCard)
        #expect(!model.hasUndoableSteps)

        model.reveal()
        undoManager.beginUndoGrouping()
        model.suspendCurrentCard()
        undoManager.endUndoGrouping()
        #expect(document.card(withID: card.id)?.isSuspended == true)
        #expect(document.card(withID: card.id)?.learningState == nil)
        #expect(model.currentCard?.id != card.id)
        #expect(model.stage == .asking)
        #expect(model.hasUndoableSteps)

        undoManager.undo()
        #expect(document.card(withID: card.id) == card)
        #expect(model.currentCard == card)
        #expect(!model.hasUndoableSteps)
    }

    /// Once the plan is done, the stream goes on with the practice of the mistakes of today,
    /// which changes no card, as on the Mac; a practice entry of its own ends at rest.
    @Test func practicingMistakesLeavesScheduleAlone() throws {
        let (document, undoManager) = try makeDocument(questions: ["dom"])
        let model = StudyModel(document: document)
        let id = try #require(model.currentCard?.id)
        #expect(!model.rest.canKeepGoing)

        model.reveal()
        grade(model, .again, undoManager: undoManager)
        model.reveal()
        grade(model, .easy, undoManager: undoManager)
        #expect(model.isResting)
        #expect(!model.isPracticing)
        #expect(model.rest.canKeepGoing)

        let before = document.deck
        model.keepGoing()
        #expect(model.isPracticing)
        #expect(!model.isResting)
        #expect(model.streamStage == .practiceMistakes)
        #expect(model.currentCard?.id == id)
        model.reveal()
        grade(model, .easy, undoManager: undoManager)
        // Then the newest words, again and again.
        #expect(model.streamStage == .practiceNewest)
        #expect(document.deck == before)

        let practice = StudyModel(document: document, entry: .practiceMistakes)
        #expect(practice.isPracticing)
        practice.reveal()
        grade(practice, .easy, undoManager: undoManager)
        #expect(practice.isResting)
        #expect(practice.rest.isPracticeOnly)
        #expect(document.deck == before)
    }

    /// The plan is done: the stream rests, then reviews ahead, with ordinary reviews that undo
    /// takes back across the segments.
    @Test func afterThePlanTheStreamRestsAndReviewsAhead() throws {
        let lastReview = created.addingTimeInterval(-5 * 86400)
        let state = LearningState(phase: .review, stability: 10, difficulty: 5, lastReview: lastReview, due: created.addingTimeInterval(5 * 86400), reviews: 1)
        let ahead = Card(question: "ahead", answer: "x", created: created, learningState: state, log: [ReviewLogEntry(date: lastReview, grade: .good, mode: .revealed)])
        let new = Card(text: CardText(question: "new", answer: "x")!, created: created)
        let document = try VocabularyDocument(deck: Deck(cards: [new, ahead]), clock: StudyClock { [created] in created.addingTimeInterval(60) })
        let undoManager = UndoManager()
        undoManager.groupsByEvent = false
        document.attachUndoManager(undoManager)
        let model = StudyModel(document: document)
        #expect(model.streamStage == .plan)
        #expect(model.rest.nextDue != nil)

        model.reveal()
        grade(model, .good, undoManager: undoManager)
        model.reveal()
        grade(model, .good, undoManager: undoManager)
        #expect(model.isResting)
        #expect(model.rest.recap.cards == 1)
        #expect(model.rest.canKeepGoing)

        model.keepGoing()
        #expect(model.streamStage == .reviewAhead)
        #expect(model.currentCard?.id == ahead.id)
        model.reveal()
        grade(model, .good, undoManager: undoManager)
        #expect(document.card(withID: ahead.id)?.log.count == 2)
        #expect(model.hasUndoableSteps)

        undoManager.undo()
        #expect(model.streamStage == .reviewAhead)
        #expect(document.card(withID: ahead.id) == ahead)
    }

    /// "+10 new" offers the cards beyond the daily limit, with what they cost, and asks them.
    @Test func newCardsBeyondTheLimitComeOnRequest() throws {
        var learningOptions = LearningOptions()
        learningOptions.newCardsPerSession = 1
        let cards = (0..<15).map { Card(text: CardText(question: "q\($0)", answer: "x")!, created: created) }
        let document = try VocabularyDocument(deck: Deck(learningOptions: learningOptions, cards: cards), clock: StudyClock { [created] in created.addingTimeInterval(60) })
        let undoManager = UndoManager()
        undoManager.groupsByEvent = false
        document.attachUndoManager(undoManager)
        let model = StudyModel(document: document)
        #expect(model.session.totalCount == 1)
        #expect(model.extraNew?.cards == StudyStream.newCardChunk)
        #expect((model.extraNew?.reviewsPerDay ?? 0) > 0)

        for _ in 0..<learningOptions.steps {
            model.reveal()
            grade(model, .good, undoManager: undoManager)
        }
        #expect(model.isResting)
        model.addNewCards()
        #expect(!model.isResting)
        #expect(model.session.totalCount == StudyStream.newCardChunk)
        #expect(model.currentCard?.isNew == true)
    }

    /// The view speaks a Greek question when this changes: once per move to a card, also
    /// when undo brings a card back, and not for a reveal.
    @Test func questionNumberCountsEveryMoveOnce() throws {
        let (document, undoManager) = try makeDocument()
        let model = StudyModel(document: document)
        #expect(model.questionNumber == 0)

        model.reveal()
        #expect(model.questionNumber == 0)
        grade(model, .good, undoManager: undoManager)
        #expect(model.questionNumber == 1)
        undoManager.undo()
        #expect(model.questionNumber == 2)
    }

    @Test func streamWithoutCardsRests() throws {
        let (document, _) = try makeDocument(questions: [])
        let model = StudyModel(document: document)
        #expect(model.isResting)
        #expect(model.currentCard == nil)
        #expect(!model.rest.canKeepGoing)
        #expect(model.extraNew == nil)
    }
}
