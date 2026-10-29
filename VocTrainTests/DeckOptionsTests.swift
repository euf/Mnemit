import Foundation
import SwiftUI
import Testing

@testable import VocTrain
@testable import VocabCore

/// The bindings of the options screen: each change goes through the document, as one undo
/// step, and reads back from the saved deck.
@MainActor @Suite(.timeLimit(.minutes(1)))
struct DeckOptionsTests {
    func makeDocument(attachingUndoManager: Bool = true) throws -> (VocabularyDocument, UndoManager) {
        let created = Date(timeIntervalSince1970: 1_791_216_000)
        let card = Card(text: CardText(question: "dom", answer: "Haus")!, created: created)
        let document = try VocabularyDocument(deck: Deck(cards: [card]), clock: StudyClock { created.addingTimeInterval(60) })
        let undoManager = UndoManager()
        undoManager.groupsByEvent = false
        if attachingUndoManager { document.attachUndoManager(undoManager) }
        return (document, undoManager)
    }

    func step(_ undoManager: UndoManager, _ action: () -> Void) {
        undoManager.beginUndoGrouping()
        action()
        undoManager.endUndoGrouping()
    }

    @Test func aChangeIsOneUndoStepUnderTheNameOfTheMac() throws {
        let (document, undoManager) = try makeDocument()
        let recall = document.option(\.targetRecall)
        #expect(recall.wrappedValue == 0.9)

        step(undoManager) { recall.wrappedValue = 0.85 }
        #expect(recall.wrappedValue == 0.85)
        #expect(document.deck.learningOptions.targetRecall == 0.85)
        #expect(undoManager.undoActionName == String(localized: "Change Learning Options"))

        undoManager.undo()
        #expect(recall.wrappedValue == 0.9)
        #expect(document.deck.learningOptions == LearningOptions())
        undoManager.redo()
        #expect(recall.wrappedValue == 0.85)
    }

    @Test func everyOptionOfTheScreenChangesAloneAndSurvivesTheFile() throws {
        let (document, undoManager) = try makeDocument()
        step(undoManager) { document.option(\.newCardsPerSession).wrappedValue = 15 }
        step(undoManager) { document.option(\.targetRecall).wrappedValue = 0.8 }
        step(undoManager) { document.option(\.leechThreshold).wrappedValue = 5 }
        step(undoManager) { document.option(\.leechAction).wrappedValue = .suspend }
        step(undoManager) { document.option(\.maximumInterval).wrappedValue = 365 }
        step(undoManager) { document.option(\.steps).wrappedValue = 3 }
        step(undoManager) { document.option(\.maximumReviewsPerDay).wrappedValue = 200 }

        var expected = LearningOptions()
        expected.newCardsPerSession = 15
        expected.targetRecall = 0.8
        expected.leechThreshold = 5
        expected.leechAction = .suspend
        expected.maximumInterval = 365
        expected.steps = 3
        expected.maximumReviewsPerDay = 200
        #expect(document.deck.learningOptions == expected)

        // Saved and read again, as the deck is on the phone.
        let saved = try DeckFile.decode(document.fileWrapper())
        #expect(saved.learningOptions == expected)
        #expect(saved.learningOptions.newCardsPerSession == 15)
        #expect(saved.learningOptions.maximumReviewsPerDay == 200)

        // One step each: seven undos bring back the defaults.
        for _ in 0..<7 { undoManager.undo() }
        #expect(!undoManager.canUndo)
        #expect(document.deck.learningOptions == LearningOptions())
    }

    @Test func newCardsPerDayStaysLimitedOrUnlimitedInTheFile() throws {
        let (document, undoManager) = try makeDocument()
        #expect(document.deck.learningOptions.newCardsPerSession == nil)
        step(undoManager) { document.option(\.newCardsPerSession).wrappedValue = 15 }
        #expect(try DeckFile.decode(document.fileWrapper()).learningOptions.newCardsPerSession == 15)
        step(undoManager) { document.option(\.newCardsPerSession).wrappedValue = nil }
        #expect(try DeckFile.decode(document.fileWrapper()).learningOptions.newCardsPerSession == nil)
    }

    @Test func maximumReviewsPerDayStaysLimitedOrUnlimitedInTheFile() throws {
        let (document, undoManager) = try makeDocument()
        #expect(document.deck.learningOptions.maximumReviewsPerDay == nil)
        step(undoManager) { document.option(\.maximumReviewsPerDay).wrappedValue = 200 }
        #expect(try DeckFile.decode(document.fileWrapper()).learningOptions.maximumReviewsPerDay == 200)
        step(undoManager) { document.option(\.maximumReviewsPerDay).wrappedValue = nil }
        #expect(try DeckFile.decode(document.fileWrapper()).learningOptions.maximumReviewsPerDay == nil)
        step(undoManager) { document.option(\.maximumReviewsPerDay).wrappedValue = 0 }
        #expect(document.deck.learningOptions.maximumReviewsPerDay == LearningOptions.reviewLimitRange.lowerBound)
    }

    @Test func restoreDefaultsIsOneUndoStepAndKeepsTheParametersAndThePause() throws {
        let (document, undoManager) = try makeDocument()
        var custom = LearningOptions()
        custom.targetRecall = 0.8
        custom.newCardsPerSession = 12
        custom.maximumReviewsPerDay = 150
        custom.maximumInterval = 365
        custom.steps = 4
        custom.leechThreshold = 0
        custom.leechAction = .suspend
        custom.updatesParametersAutomatically = false
        var weights = FSRSParameters.default.weights
        weights[0] += 0.05
        custom.parameters = FSRSParameters(weights)!
        custom.lastAutoFit = LearningOptions.AutoFit(date: Date(timeIntervalSince1970: 1_791_216_000), reviewCount: 900, adopted: true)
        custom.isPaused = true
        step(undoManager) { document.option(\.self).wrappedValue = custom }
        #expect(document.deck.learningOptions == custom)

        step(undoManager) { document.restoreDefaultLearningOptions() }
        var expected = LearningOptions()
        expected.parameters = custom.parameters
        expected.lastAutoFit = custom.lastAutoFit
        expected.isPaused = true
        #expect(document.deck.learningOptions == expected)
        #expect(undoManager.undoActionName == String(localized: "Restore Defaults"))
        #expect(try DeckFile.decode(document.fileWrapper()).learningOptions == expected)

        // One undo step brings every option back.
        undoManager.undo()
        #expect(document.deck.learningOptions == custom)
        undoManager.redo()
        #expect(document.deck.learningOptions == expected)
    }

    @Test func restoreDefaultsChangesNothingWhileTheDocumentCannotBeChanged() throws {
        let (document, undoManager) = try makeDocument(attachingUndoManager: false)
        document.restoreDefaultLearningOptions()
        #expect(!undoManager.canUndo)
        let (ready, readyUndo) = try makeDocument()
        #expect(ready.deck.learningOptions == LearningOptions())
        #expect(ready.deck.learningOptions.restoringDefaults() == ready.deck.learningOptions)
        step(readyUndo) { ready.restoreDefaultLearningOptions() }
        // Already at the defaults: no change, no undo step.
        #expect(readyUndo.undoActionName != String(localized: "Restore Defaults"))
    }

    @Test func allOptionsTogetherAreOneChangeToo() throws {
        let (document, undoManager) = try makeDocument()
        var parameters = LearningOptions()
        parameters.steps = 4
        parameters.fuzzing = false
        step(undoManager) { document.option(\.self).wrappedValue = parameters }
        #expect(document.deck.learningOptions.steps == 4)
        #expect(!document.deck.learningOptions.fuzzing)
        undoManager.undo()
        #expect(document.deck.learningOptions == LearningOptions())
    }

    @Test func aValueOutsideItsRangeIsClamped() throws {
        let (document, undoManager) = try makeDocument()
        let recall = document.option(\.targetRecall)
        step(undoManager) { recall.wrappedValue = 0.99 }
        #expect(recall.wrappedValue == LearningOptions.targetRecallRange.upperBound)
        step(undoManager) { document.option(\.leechThreshold).wrappedValue = 500 }
        #expect(document.deck.learningOptions.leechThreshold == LearningOptions.leechThresholdRange.upperBound)
    }

    @Test func nothingChangesWhileTheDocumentCannotBeChanged() throws {
        let (document, undoManager) = try makeDocument(attachingUndoManager: false)
        document.option(\.steps).wrappedValue = 4
        #expect(document.deck.learningOptions == LearningOptions())
        #expect(!undoManager.canUndo)
    }
}
