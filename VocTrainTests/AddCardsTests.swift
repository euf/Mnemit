import Foundation
import Testing

@testable import VocTrain
@testable import VocabCore

/// What the Add Cards sheet makes of what is typed: the preview of a list, the two cards of
/// a word, and how they join the deck.
@MainActor @Suite(.timeLimit(.minutes(1)))
struct AddCardsTests {
    let created = Date(timeIntervalSince1970: 1_791_216_000)

    func makeDocument(cards: [Card] = []) throws -> (VocabularyDocument, UndoManager) {
        let document = try VocabularyDocument(deck: Deck(cards: cards), clock: StudyClock { created.addingTimeInterval(60) })
        let undoManager = UndoManager()
        undoManager.groupsByEvent = false
        document.attachUndoManager(undoManager)
        return (document, undoManager)
    }

    func makeCard(_ question: String, answer: String = "x", note: String? = nil, kind: CardKind? = nil) -> Card {
        Card(text: CardText(question: question, answer: answer)!, note: note, kind: kind, created: created)
    }

    /// Runs `action` in an undo group of its own, as one event does.
    func step(_ undoManager: UndoManager, _ action: () -> Void) {
        undoManager.beginUndoGrouping()
        action()
        undoManager.endUndoGrouping()
    }

    // MARK: The preview of a list

    @Test func eachWordMakesTwoCardsAndTheLinesThatAreNoWordAreNamed() {
        let text = """
            κλέβω = to steal

            a line without a separator
            η κλοπή – theft
            = a translation without a word
            theft = η κλοπή 2
            """
        let preview = WordListPreview(text: text, deck: Deck(), created: created)

        #expect(preview.rows.map(\.entry.greek) == ["κλέβω", "η κλοπή", "η κλοπή 2"])
        #expect(preview.rows.map(\.entry.translation) == ["to steal", "theft", "theft"])
        #expect(preview.rows.allSatisfy { $0.cards.map(\.kind) == [.recognition, .production] })
        #expect(preview.rows.allSatisfy { Set($0.cards.compactMap(\.note)).count == 1 })
        #expect(preview.rows.allSatisfy { $0.isSelectedByDefault })
        // Numbered from 1 over the whole text, the blank line included.
        #expect(preview.invalidLines.map(\.number) == [3, 5])
        #expect(preview.invalidLines.map(\.text) == ["a line without a separator", "= a translation without a word"])
    }

    @Test func aWordTheDeckHasOrAnEarlierLineMadeIsFlaggedAndUncheckedByDefault() throws {
        let deck = try Deck(cards: [
            // Both cards of a word, by their word key; a card of an older deck without one.
            makeCard("κλέβω", answer: "to steal", note: "κλέβω", kind: .recognition),
            makeCard("to steal", answer: "κλέβω", note: "κλέβω", kind: .production),
            makeCard("η κλοπή", answer: "theft"),
        ])
        let text = """
            Κλέβω = to rob
            η ΚΛΟΠΉ = the theft
            ο κλέφτης = thief
            ο κλέφτης = the thief
            το σπίτι = the house
            """
        let preview = WordListPreview(text: text, deck: deck, created: created)

        #expect(preview.rows.count == 5)
        #expect(
            preview.rows.map(\.duplicate) == [
                .inDeck, .inDeck, nil, .inFile(question: "ο κλέφτης", answer: "thief"), nil,
            ])
        #expect(preview.rows.map(\.isSelectedByDefault) == [false, false, true, false, true])
        // A row of its own for each line, so the learner can check one of a pair.
        #expect(Set(preview.rows.map(\.id)).count == 5)
        #expect(preview.rows.allSatisfy { $0.cards.count == 2 })
    }

    @Test func aListWithNothingUsableMakesNoRows() {
        #expect(WordListPreview(text: "", deck: Deck(), created: created).rows.isEmpty)
        let preview = WordListPreview(text: "  \n one\n two = ", deck: Deck(), created: created)
        #expect(preview.rows.isEmpty)
        #expect(preview.invalidLines.map(\.number) == [2, 3])
    }

    @Test func theCheckedRowsJoinTheDeckAsOneUndoStep() throws {
        let (document, undoManager) = try makeDocument(cards: [makeCard("κλέβω", answer: "to steal", note: "κλέβω", kind: .recognition)])
        let preview = WordListPreview(text: "κλέβω = to steal\nη κλοπή = theft\nο κλέφτης = thief", deck: document.deck, created: created)
        let cards = preview.rows.filter(\.isSelectedByDefault).flatMap(\.cards)
        #expect(cards.count == 4)

        var added = 0
        step(undoManager) { added = document.addLessonCards(cards) }
        #expect(added == 4)
        #expect(document.deck.cards.count == 5)
        #expect(undoManager.undoActionName == String(localized: "Add Lesson Words"))
        undoManager.undo()
        #expect(document.deck.cards.map(\.question) == ["κλέβω"])
        #expect(!undoManager.canUndo)
    }

    // MARK: One card, both directions

    @Test func oneCardInBothDirectionsMakesTwoLinkedCardsInOneUndoStep() throws {
        let (document, undoManager) = try makeDocument()
        let text = try #require(CardText(question: "ο κλέφτης", answer: "thief", hint: "noun"))

        var added = 0
        step(undoManager) { added = document.add(WordPair.cards(for: text, created: created)) }

        #expect(added == 2)
        let cards = document.deck.cards
        #expect(cards.map(\.kind) == [.recognition, .production])
        #expect(cards.map(\.question) == ["ο κλέφτης", "thief"])
        #expect(cards.map(\.answer) == ["thief", "ο κλέφτης"])
        #expect(cards.map(\.hint) == ["noun", "noun"])
        // The word key of Lesson Words, shared: the deck knows them as siblings.
        #expect(cards.map(\.note) == ["κλέφτης#ο", "κλέφτης#ο"])
        #expect(undoManager.undoActionName == String(localized: "Add Cards"))
        undoManager.undo()
        #expect(document.deck.cards.isEmpty)
        #expect(!undoManager.canUndo)
        undoManager.redo()
        #expect(document.deck.cards.count == 2)
    }

    @Test func theGreekSideAsksInRecognitionWhicheverSideWasTypedFirst() throws {
        let typedBackwards = WordPair.cards(for: try #require(CardText(question: "thief", answer: "ο κλέφτης")), created: created)
        #expect(typedBackwards.map(\.question) == ["ο κλέφτης", "thief"])
        #expect(typedBackwards.map(\.kind) == [.recognition, .production])
        #expect(typedBackwards.map(\.note) == ["κλέφτης#ο", "κλέφτης#ο"])

        // No Greek at all: the question asks in recognition, as typed.
        let other = WordPair.cards(for: try #require(CardText(question: "dom", answer: "Haus")), created: created)
        #expect(other.map(\.question) == ["dom", "Haus"])
        #expect(other.map(\.note) == ["dom", "dom"])
    }

    @Test func aSingleCardKeepsNoWordKey() throws {
        let (document, undoManager) = try makeDocument()
        var added = 0
        step(undoManager) { added = AddCardsSheet.add(CardText(question: "dom", answer: "Haus")!, bothDirections: false, to: document) }
        #expect(added == 1)
        #expect(document.deck.cards.map(\.note) == [nil])
        #expect(document.deck.cards.map(\.kind) == [nil])
        #expect(undoManager.undoActionName == String(localized: "Add Card"))
    }

    /// What the Add button does with the fields: two cards or one, and nothing while the
    /// document can't be changed, so the fields stay as typed.
    @Test func theAddButtonAddsTheDirectionsTheToggleAsksFor() throws {
        let (document, undoManager) = try makeDocument()
        let text = try #require(CardText(question: "ο κλέφτης", answer: "thief"))
        var both = 0
        step(undoManager) { both = AddCardsSheet.add(text, bothDirections: true, to: document) }
        #expect(both == 2)
        #expect(document.deck.cards.count == 2)

        let detached = try VocabularyDocument(deck: Deck(), clock: StudyClock { created })
        #expect(AddCardsSheet.add(text, bothDirections: true, to: detached) == 0)
        #expect(AddCardsSheet.add(text, bothDirections: false, to: detached) == 0)
        #expect(detached.deck.cards.isEmpty)
    }
}
