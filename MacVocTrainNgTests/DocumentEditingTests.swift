import Foundation
import Testing

@testable import MacVocTrain
@testable import VocabCore

/// The editing methods both apps share (`VocabularyDocument+Editing`): the iPhone's tests
/// run them on iOS, these on the Mac.
@MainActor
struct DocumentEditingTests {
    @Test func theWordKeyAndTheKindOfACardAreEditable() throws {
        let dom = Card(question: "dom", answer: "Haus")
        let document = try VocabularyDocument(deck: Deck(cards: [dom]))
        let undoManager = makeUndoManager(for: document)

        step(undoManager) { document.setNote(" dom ", kind: .recognition, of: dom.id) }
        #expect((document.deck.cards[0].note, document.deck.cards[0].kind) == ("dom", .recognition))
        #expect(undoManager.undoActionName == String(localized: "Edit Card"))

        step(undoManager) { document.setKind(.production, of: dom.id) }
        #expect((document.deck.cards[0].note, document.deck.cards[0].kind) == ("dom", .production))

        step(undoManager) { document.setNote(nil, kind: nil, of: dom.id) }
        #expect((document.deck.cards[0].note, document.deck.cards[0].kind) == (nil, nil))

        for _ in 0..<3 {
            undoManager.undo()
        }
        #expect(document.deck.cards.unstamped == [dom])
        #expect(!undoManager.canUndo)
    }

    @Test func textAndWordKeyAreOneUndoStep() throws {
        let dom = Card(text: CardText(question: "dom", answer: "Haus")!, note: "dom", kind: .recognition, created: Date(timeIntervalSince1970: 1_791_216_000))
        let document = try VocabularyDocument(deck: Deck(cards: [dom]))
        let undoManager = makeUndoManager(for: document)

        step(undoManager) { document.editCard(dom.id, text: CardText(question: "dom", answer: "Heim")!, note: "dom2") }
        #expect((document.deck.cards[0].answer, document.deck.cards[0].note, document.deck.cards[0].kind) == ("Heim", "dom2", .recognition))
        undoManager.undo()
        #expect(document.deck.cards.unstamped == [dom])
        #expect(!undoManager.canUndo)
    }

    @Test func cardsAreAddedAsOneStepNamedByTheirNumber() throws {
        let document = VocabularyDocument()
        let undoManager = makeUndoManager(for: document)
        let created = Date(timeIntervalSince1970: 1_791_216_000)
        let both = [
            Card(text: CardText(question: "dom", answer: "Haus")!, note: "dom", kind: .recognition, created: created),
            Card(text: CardText(question: "Haus", answer: "dom")!, note: "dom", kind: .production, created: created),
        ]

        var added = 0
        step(undoManager) { added = document.add(both) }
        #expect(added == 2)
        #expect(document.deck.cards.map(\.kind) == [.recognition, .production])
        #expect(undoManager.undoActionName == String(localized: "Add Cards"))
        // The same cards again add nothing, and register nothing: no open group, no step.
        added = document.add(both)
        #expect(added == 0)

        undoManager.undo()
        #expect(document.deck.cards.isEmpty)
        step(undoManager) { added = document.add([both[0]]) }
        #expect(added == 1)
        #expect(undoManager.undoActionName == String(localized: "Add Card"))
    }
}
