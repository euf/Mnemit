import Foundation
import Testing

@testable import MacVocTrain
@testable import VocabCore

/// The changes of the card browser, see `VocabularyDocument+Browser.swift`.
@MainActor
struct DocumentBrowserTests {
    let lieben = Card(question: "lieben", answer: "αγαπώ", note: "αγαπώ", kind: .production)

    func makeDocument() throws -> (VocabularyDocument, UndoManager) {
        let document = try VocabularyDocument(deck: Deck(cards: [lieben]))
        return (document, makeUndoManager(for: document))
    }

    @Test func theWordKeyIsSetClearedAndUndone() throws {
        let (document, undoManager) = try makeDocument()

        step(undoManager) { document.setNote("  agapo ", of: lieben.id) }
        #expect(document.card(withID: lieben.id)?.note == "agapo")
        #expect(undoManager.undoActionName == "Edit Card" || undoManager.undoActionName == "Karte bearbeiten")

        step(undoManager) { document.setNote("", of: lieben.id) }
        #expect(document.card(withID: lieben.id)?.note == nil)

        undoManager.undo()
        #expect(document.card(withID: lieben.id)?.note == "agapo")
        undoManager.undo()
        #expect(document.card(withID: lieben.id) == lieben)
    }

    /// Only the key changes: the card keeps its kind, texts and learning state.
    @Test func theCardKeepsEverythingElse() throws {
        let state = LearningState(phase: .review, stability: 5, difficulty: 5, lastReview: Date(), due: Date(), reviews: 3, lapses: 1)
        let studied = Card(question: "dom", answer: "Haus", hint: "alt", note: "dom", kind: .recognition, learningState: state)
        let document = try VocabularyDocument(deck: Deck(cards: [studied]))
        let undoManager = makeUndoManager(for: document)

        step(undoManager) { document.setNote("haus", of: studied.id) }
        var expected = studied
        expected.note = "haus"
        #expect(document.card(withID: studied.id) == expected)
    }

    @Test func aKeyThatStaysRegistersNothing() throws {
        let (document, undoManager) = try makeDocument()
        // Outside a group: registering anything would throw.
        document.setNote("αγαπώ", of: lieben.id)
        document.setNote(" αγαπώ ", of: lieben.id)
        document.setNote("x", of: UUID())
        #expect(!undoManager.canUndo)
        #expect(document.card(withID: lieben.id) == lieben)
    }

    @Test func nothingChangesWithoutAnUndoManager() throws {
        let document = try VocabularyDocument(deck: Deck(cards: [lieben]))
        document.setNote("agapo", of: lieben.id)
        #expect(document.card(withID: lieben.id) == lieben)
    }
}
