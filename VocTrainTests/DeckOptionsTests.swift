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
        step(undoManager) { document.option(\.newCardOrder).wrappedValue = .newestFirst }
        step(undoManager) { document.option(\.targetRecall).wrappedValue = 0.8 }
        step(undoManager) { document.option(\.newProductionPerSession).wrappedValue = nil }
        step(undoManager) { document.option(\.productionUnlockDays).wrappedValue = 0 }
        step(undoManager) { document.option(\.leechThreshold).wrappedValue = 5 }
        step(undoManager) { document.option(\.maximumInterval).wrappedValue = 365 }
        step(undoManager) { document.option(\.steps).wrappedValue = 3 }
        step(undoManager) { document.option(\.fuzzing).wrappedValue = false }
        step(undoManager) { document.option(\.revealedRecallWeight).wrappedValue = 0.5 }

        var expected = LearningOptions()
        expected.newCardsPerSession = 15
        expected.newCardOrder = .newestFirst
        expected.targetRecall = 0.8
        expected.newProductionPerSession = nil
        expected.productionUnlockDays = 0
        expected.leechThreshold = 5
        expected.maximumInterval = 365
        expected.steps = 3
        expected.fuzzing = false
        expected.revealedRecallWeight = 0.5
        #expect(document.deck.learningOptions == expected)

        // Saved and read again, as the deck is on the phone.
        let saved = try DeckFile.decode(document.fileWrapper())
        #expect(saved.learningOptions == expected)
        // Unlimited stays unlimited, and limited stays limited.
        #expect(saved.learningOptions.newProductionPerSession == nil)
        #expect(saved.learningOptions.newCardsPerSession == 15)

        // One step each: ten undos bring back the defaults.
        for _ in 0..<10 { undoManager.undo() }
        #expect(!undoManager.canUndo)
        #expect(document.deck.learningOptions == LearningOptions())
    }

    @Test func allOptionsTogetherAreOneChangeToo() throws {
        let (document, undoManager) = try makeDocument()
        var parameters = LearningOptions()
        parameters.steps = 4
        parameters.optimizeFromRevealed = false
        step(undoManager) { document.option(\.self).wrappedValue = parameters }
        #expect(document.deck.learningOptions.steps == 4)
        #expect(!document.deck.learningOptions.optimizeFromRevealed)
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
        step(undoManager) { document.option(\.revealedRecallWeight).wrappedValue = 0 }
        #expect(document.deck.learningOptions.revealedRecallWeight == LearningOptions.revealedRecallWeightRange.lowerBound)
    }

    @Test func nothingChangesWhileTheDocumentCannotBeChanged() throws {
        let (document, undoManager) = try makeDocument(attachingUndoManager: false)
        document.option(\.steps).wrappedValue = 4
        #expect(document.deck.learningOptions == LearningOptions())
        #expect(!undoManager.canUndo)
    }
}
