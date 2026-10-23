import Foundation
import Testing

@testable import MacVocTrain
@testable import VocabCore

/// The part of the study stream that Mac and iPhone share: grades, undo and redo, and
/// cards deleted while the stream runs (#264).
@MainActor
struct SessionDriverTests {
    /// A stream over new cards, with a listener as its delegate: today's plan, or with
    /// `practicing` the practice of the newest words. The test keeps the undo manager and
    /// the listener, which the document and the driver hold weakly.
    private func makeDriver(cards: Int, practicing: Bool = false) throws -> (SessionDriver, UndoManager, DriverListener) {
        var learningOptions = LearningOptions()
        learningOptions.steps = 1
        learningOptions.fuzzing = false
        let document = try VocabularyDocument(deck: Deck(learningOptions: learningOptions, cards: (0..<cards).map { Card(question: "q\($0)", answer: "a\($0)") }), calendar: .testing)
        let undoManager = makeUndoManager(for: document)
        let driver = SessionDriver(document: document, stream: makeStream(for: document, practicing: practicing))
        let listener = DriverListener()
        driver.delegate = listener
        return (driver, undoManager, listener)
    }

    private func makeStream(for document: VocabularyDocument, practicing: Bool = false) -> StudyStream {
        if practicing {
            return StudyStream(practicingNewestWordsIn: document.deck, at: document.clock.now)
        }
        return StudyStream(deck: document.deck, at: document.clock.now, calendar: document.calendar)
    }

    @Test func undoAndRedoBringBackTheCardAndThePlace() throws {
        let (driver, undoManager, listener) = try makeDriver(cards: 2)
        let document = driver.document
        let first = try #require(driver.currentCard)

        var recorded = false
        step(undoManager) { recorded = driver.grade(.good) }
        #expect(recorded)
        #expect(document.card(withID: first.id)?.log.map(\.grade) == [.good])
        #expect(driver.currentCard?.id != first.id)
        #expect(driver.session.reviewCount == 1)
        #expect(listener.moves == 1)

        undoManager.undo()
        #expect(document.card(withID: first.id) == first)
        #expect(driver.currentCard == first)
        #expect(driver.session.reviewCount == 0)
        #expect(listener.restores == 1)
        #expect(listener.moves == 2)
        #expect(!undoManager.canUndo)  // card and place in one step

        undoManager.redo()
        #expect(document.card(withID: first.id)?.log.map(\.grade) == [.good])
        #expect(driver.currentCard?.id != first.id)
        #expect(driver.session.reviewCount == 1)
        #expect(listener.restores == 2)
    }

    @Test func undoOfAPracticeReviewBringsBackThePlace() throws {
        let (driver, undoManager, _) = try makeDriver(cards: 2, practicing: true)
        let card = try #require(driver.currentCard)
        let deck = driver.document.deck

        step(undoManager) { driver.grade(.good) }
        #expect(driver.session.reviewCount == 1)
        #expect(driver.document.deck == deck)
        #expect(undoManager.undoActionName == String(localized: "Review"))

        undoManager.undo()
        #expect(driver.session.reviewCount == 0)
        #expect(driver.currentCard == card)

        undoManager.redo()
        #expect(driver.session.reviewCount == 1)
    }

    /// Undo takes the card back; only the stream that made the review puts its place back.
    @Test func undoingAReviewOfAnEarlierStreamOnlyTakesBackTheCard() throws {
        let (driver, undoManager, listener) = try makeDriver(cards: 2)
        let first = try #require(driver.currentCard)
        step(undoManager) { driver.grade(.good) }
        let later = SessionDriver(document: driver.document, stream: makeStream(for: driver.document))
        let laterListener = DriverListener()
        later.delegate = laterListener
        let stream = later.stream.id
        let current = later.currentCard

        undoManager.undo()
        #expect(driver.document.card(withID: first.id) == first)
        #expect(listener.restores == 1)
        #expect(later.stream.id == stream)
        #expect(later.currentCard == current)
        #expect(laterListener.restores == 0)
    }

    /// The plan, then the new cards Push On adds beyond the limit; undo goes back through both card by card,
    /// and redo forward again.
    @Test func undoAndRedoReachAcrossTheSegmentsOfTheStream() throws {
        var learningOptions = LearningOptions()
        learningOptions.steps = 1
        learningOptions.fuzzing = false
        learningOptions.newCardsPerSession = 1
        let planned = Card(question: "planned", answer: "geplant")
        let pushed = Card(question: "pushed", answer: "gedrängt")
        let document = try VocabularyDocument(deck: Deck(learningOptions: learningOptions, cards: [planned, pushed]), calendar: .testing)
        let undoManager = makeUndoManager(for: document)
        let driver = SessionDriver(document: document, stream: makeStream(for: document))
        #expect(driver.stream.stage == .plan)
        #expect(driver.currentCard?.id == planned.id)

        step(undoManager) { driver.grade(.good) }
        #expect(driver.isResting)
        #expect(driver.extraNew?.cards == 1)
        driver.addNewCards()
        #expect(driver.stream.stage == .plan)
        #expect(driver.currentCard?.id == pushed.id)
        step(undoManager) { driver.grade(.good) }
        #expect(driver.isResting)
        #expect(driver.stream.stepCount == 2)

        undoManager.undo()
        #expect(driver.stream.stage == .plan)
        #expect(driver.currentCard?.id == pushed.id)
        #expect(document.card(withID: pushed.id)?.isNew == true)
        #expect(driver.stream.stepCount == 1)

        undoManager.undo()
        #expect(driver.stream.stage == .plan)
        #expect(driver.currentCard?.id == planned.id)
        #expect(document.card(withID: planned.id)?.isNew == true)
        #expect(driver.stream.stepCount == 0)

        undoManager.redo()
        #expect(driver.isResting)
        #expect(document.card(withID: planned.id)?.log.count == 1)

        undoManager.redo()
        #expect(driver.isResting)
        #expect(document.card(withID: pushed.id)?.log.count == 1)
        #expect(driver.stream.stepCount == 2)
    }

    /// Suspending is undone like a review: the card and the place in one step (#290).
    @Test func suspendingTheCardBeingAskedMovesOnUntilUndone() throws {
        let (driver, undoManager, listener) = try makeDriver(cards: 2)
        let document = driver.document
        let first = try #require(driver.currentCard)

        var suspended = false
        step(undoManager) { suspended = driver.suspendCurrentCard() }
        #expect(suspended)
        #expect(document.card(withID: first.id)?.isSuspended == true)
        #expect(driver.currentCard != nil)
        #expect(driver.currentCard?.id != first.id)
        #expect(driver.session.totalCount == 1)
        #expect(driver.session.suspendedCount == 1)
        #expect(driver.session.reviewCount == 0)
        #expect(listener.moves == 1)
        #expect(undoManager.undoActionName == String(localized: "Suspend Card"))

        undoManager.undo()
        #expect(document.card(withID: first.id) == first)
        #expect(driver.currentCard == first)
        #expect(driver.session.totalCount == 2)
        #expect(driver.session.suspendedCount == 0)
        #expect(!undoManager.canUndo)

        undoManager.redo()
        #expect(document.card(withID: first.id)?.isSuspended == true)
        #expect(driver.currentCard?.id != first.id)
        #expect(driver.session.suspendedCount == 1)
    }

    @Test func suspendingTheLastCardOfThePlanRests() throws {
        let (driver, undoManager, _) = try makeDriver(cards: 1)
        step(undoManager) { driver.suspendCurrentCard() }
        #expect(driver.isResting)
        #expect(driver.currentCard == nil)
        #expect(!driver.suspendCurrentCard())
    }

    /// E.g. after a merge with a version from the iPhone that suspended it.
    @Test func aCardSuspendedMeanwhileIsSkipped() throws {
        let (driver, undoManager, listener) = try makeDriver(cards: 3)
        let current = try #require(driver.currentCard)
        let other = try #require(driver.document.deck.cards.first { $0.id != current.id })

        step(undoManager) { driver.document.setSuspended(true, of: [current.id, other.id]) }
        let remaining = try #require(driver.currentCard)
        #expect(remaining.id != current.id && remaining.id != other.id)
        #expect(listener.moves == 1)
        // Only the learner's own suspensions count.
        #expect(driver.session.suspendedCount == 0)

        step(undoManager) { driver.grade(.good) }
        #expect(driver.isResting)
    }

    /// E.g. after undoing "Add Card", or after a merge with a version that deleted it.
    @Test func aDeletedCardBeingAskedIsSkipped() throws {
        let (driver, undoManager, listener) = try makeDriver(cards: 2)
        let current = try #require(driver.currentCard)

        step(undoManager) { driver.document.delete([current.id]) }
        #expect(driver.currentCard != nil)
        #expect(driver.currentCard?.id != current.id)
        #expect(driver.session.totalCount == 1)
        #expect(listener.moves == 1)
    }

    @Test func aDeletedCardLaterInTheSessionIsSkipped() throws {
        let (driver, undoManager, listener) = try makeDriver(cards: 2)
        let current = try #require(driver.currentCard)
        let other = try #require(driver.document.deck.cards.first { $0.id != current.id })

        step(undoManager) { driver.document.delete([other.id]) }
        #expect(driver.currentCard == current)
        #expect(listener.changes == 1)
        #expect(listener.moves == 0)

        step(undoManager) { driver.grade(.good) }
        #expect(driver.currentCard == nil)
        #expect(driver.isResting)
    }

    @Test func anEditOfTheCardBeingAskedShowsUp() throws {
        let (driver, undoManager, listener) = try makeDriver(cards: 1)
        let card = try #require(driver.currentCard)

        step(undoManager) { driver.document.editText(of: card.id, to: CardText(question: card.question, answer: "Heim")!) }
        #expect(driver.currentCard?.answer == "Heim")
        #expect(listener.changes == 1)
        #expect(listener.moves == 0)
    }

    /// Without an undo manager the document can't take a review, and the session stays
    /// where it is (#305).
    @Test func withoutUndoManagerNothingIsGradedOrSuspended() throws {
        let document = try VocabularyDocument(deck: Deck(cards: [Card(question: "dom", answer: "Haus"), Card(question: "kot", answer: "Katze")]), calendar: .testing)
        let driver = SessionDriver(document: document, stream: makeStream(for: document))
        let listener = DriverListener()
        driver.delegate = listener
        let deck = document.deck
        let current = driver.session.currentCardID

        #expect(!driver.grade(.good))
        #expect(!driver.suspendCurrentCard())
        #expect(document.deck == deck)
        #expect(driver.session.currentCardID == current)
        #expect(driver.session.reviewCount == 0)
        #expect(driver.session.suspendedCount == 0)
        #expect(listener.moves == 0)

        // Practice changes no card, but its undo action needs the undo manager too.
        let practice = SessionDriver(document: document, stream: makeStream(for: document, practicing: true))
        #expect(!practice.grade(.good))
        #expect(practice.session.reviewCount == 0)
    }
}

/// Counts what a `SessionDriver` tells its delegate.
@MainActor
private final class DriverListener: SessionDriverDelegate {
    var moves = 0
    var changes = 0
    var restores = 0

    func sessionDriverDidMoveOn(_ driver: SessionDriver) {
        moves += 1
    }

    func sessionDriverCardDidChange(_ driver: SessionDriver) {
        changes += 1
    }

    func sessionDriverDidRestore(_ driver: SessionDriver) {
        restores += 1
    }
}
