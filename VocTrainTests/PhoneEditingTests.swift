import Foundation
import Testing

@testable import VocTrain
@testable import VocabCore

/// The iPhone edits cards and options the way the Mac does: with undo under the same
/// names, saved through the deck's UIDocument and merged with what another device wrote.
@MainActor @Suite(.timeLimit(.minutes(3)))
struct PhoneEditingTests {
    let directory: URL
    let created = Date(timeIntervalSince1970: 1_791_216_000)

    init() throws {
        directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func makeCard(_ question: String, answer: String = "x") -> Card {
        Card(text: CardText(question: question, answer: answer)!, created: created)
    }

    /// Runs `action` in an undo group of its own, as one event does.
    func editStep(_ undoManager: UndoManager, _ action: () -> Void) {
        undoManager.beginUndoGrouping()
        action()
        undoManager.endUndoGrouping()
    }

    // MARK: Undo

    @Test func everyEditIsOneUndoStepUnderTheNameOfTheMac() throws {
        let dom = makeCard("dom", answer: "Haus")
        let kot = makeCard("kot", answer: "Katze")
        let pies = makeCard("pies", answer: "Hund")
        let studied = Card(
            question: "mysz", answer: "Maus", created: created,
            learningState: LearningState(phase: .review, stability: 5, difficulty: 5, lastReview: created, due: created)
        )
        let document = try VocabularyDocument(deck: Deck(cards: [dom, kot, pies, studied]), clock: StudyClock { created.addingTimeInterval(3600) })
        let undoManager = UndoManager()
        undoManager.groupsByEvent = false
        document.attachUndoManager(undoManager)
        var options = document.deck.learningOptions
        options.steps = 3
        var refitted = FSRSParameters.default.weights
        refitted[0] = 0.5
        let refit = ParameterRefit.Result(
            parameters: FSRSParameters(refitted), fit: LearningOptions.AutoFit(date: created, reviewCount: 700, adopted: true))
        let newCards = [makeCard("ryba"), makeCard("ptak")]
        let text = CardText(question: "dom", answer: "Haus / Heim", hint: "Gebäude")!

        let edits: [(name: String, edit: () -> Void)] = [
            ("Add Card", { document.add(CardText(question: "słońce", answer: "Sonne")!) }),
            ("Add Cards", { document.add(newCards) }),
            ("Import Cards", { document.importCards([self.makeCard("woda")]) }),
            ("Add Lesson Words", { document.addLessonCards([self.makeCard("chleb")]) }),
            ("Edit Card", { document.editText(of: dom.id, to: text) }),
            ("Edit Card", { document.editCard(kot.id, text: CardText(question: "kot", answer: "Kater")!, note: "kot") }),
            ("Edit Card", { document.setNote("pies", kind: .recognition, of: pies.id) }),
            ("Edit Card", { document.setKind(.production, of: pies.id) }),
            ("Suspend Card", { document.setSuspended(true, of: [dom.id]) }),
            ("Resume Card", { document.setSuspended(false, of: [dom.id]) }),
            ("Reset Learning State", { document.resetLearningState(of: [studied.id]) }),
            ("Change Learning Options", { document.updateLearningOptions(options) }),
            ("Update Parameters", { document.applyParameterRefit(refit) }),
            ("Delete Card", { document.delete([pies.id]) }),
            ("Delete Cards", { document.delete([dom.id, kot.id]) }),
        ]
        for (name, edit) in edits {
            editStep(undoManager, edit)
            #expect(undoManager.undoActionName == String(localized: String.LocalizationValue(name)), "\(name)")
        }
        #expect(document.deck.learningOptions.steps == 3)
        #expect(document.deck.learningOptions.parameters == refit.parameters)
        #expect(document.deck.learningOptions.lastAutoFit == refit.fit)
        #expect(document.deck.cards.map(\.question) == ["mysz", "słońce", "ryba", "ptak", "woda", "chleb"])

        for _ in edits {
            #expect(undoManager.canUndo)
            undoManager.undo()
        }
        #expect(!undoManager.canUndo)
        #expect(document.deck.cards.map(\.question) == ["dom", "kot", "pies", "mysz"])
        #expect(document.deck.cards.map(\.answer) == ["Haus", "Katze", "Hund", "Maus"])
        #expect(document.deck.cards.map(\.note) == [nil, nil, nil, nil])
        #expect(document.deck.cards.map(\.kind) == [nil, nil, nil, nil])
        #expect(document.deck.cards[3].learningState == studied.learningState)
        #expect(document.deck.learningOptions == LearningOptions())

        // And forward again.
        for _ in edits {
            #expect(undoManager.canRedo)
            undoManager.redo()
        }
        #expect(document.deck.cards.map(\.question) == ["mysz", "słońce", "ryba", "ptak", "woda", "chleb"])
        #expect(document.deck.learningOptions.steps == 3)
    }

    /// The edit sheet saves text and word key together: one undo takes both back.
    @Test func textAndWordKeyAreOneUndoStep() throws {
        let dom = Card(text: CardText(question: "dom", answer: "Haus")!, note: "dom", kind: .recognition, created: created)
        let document = try VocabularyDocument(deck: Deck(cards: [dom]))
        let undoManager = UndoManager()
        undoManager.groupsByEvent = false
        document.attachUndoManager(undoManager)

        editStep(undoManager) { document.editCard(dom.id, text: CardText(question: "dom", answer: "Heim")!, note: " ") }
        let edited = try #require(document.deck.card(withID: dom.id))
        #expect((edited.answer, edited.note, edited.kind) == ("Heim", nil, .recognition))
        undoManager.undo()
        let restored = try #require(document.deck.card(withID: dom.id))
        #expect((restored.answer, restored.note, restored.kind) == ("Haus", "dom", .recognition))
        #expect(!undoManager.canUndo)

        // A word key alone, and nothing at all, register one step or none.
        editStep(undoManager) { document.editCard(dom.id, text: CardText(question: "dom", answer: "Haus")!, note: "dom2") }
        #expect(document.deck.card(withID: dom.id)?.note == "dom2")
        undoManager.undo()
        // No open group: an empty one would count as a step.
        document.editCard(dom.id, text: CardText(question: "dom", answer: "Haus")!, note: "dom")
        #expect(!undoManager.canUndo)
    }

    @Test func withoutAnUndoManagerNothingChanges() throws {
        let dom = makeCard("dom")
        let document = try VocabularyDocument(deck: Deck(cards: [dom]))
        #expect(document.add(CardText(question: "kot", answer: "Katze")!) == nil)
        #expect(document.add([makeCard("kot")]) == 0)
        document.editCard(dom.id, text: CardText(question: "dom", answer: "Heim")!, note: "dom")
        document.setNote("dom", kind: .production, of: dom.id)
        document.setKind(.production, of: dom.id)
        #expect(document.deck.cards == [dom])
    }

    // MARK: Saving

    /// The UIDocument counts every edit through its undo manager and saves it when the deck
    /// closes, like a review.
    @Test func editsAreSavedWithTheDeck() async throws {
        let dom = makeCard("dom", answer: "Haus")
        let kot = makeCard("kot", answer: "Katze")
        let pies = makeCard("pies", answer: "Hund")
        let url = try write(Deck(cards: [dom, kot, pies]))
        let deck = OpenDeck(url: url)
        let document = try await waitForDocument(of: deck)

        document.add(CardText(question: "mysz", answer: "Maus", hint: "Tier")!)
        document.editCard(dom.id, text: CardText(question: "dom", answer: "Haus / Heim")!, note: "dom")
        document.setKind(.recognition, of: dom.id)
        document.setSuspended(true, of: [kot.id])
        document.delete([pies.id])
        var options = document.deck.learningOptions
        options.steps = 3
        document.updateLearningOptions(options)
        // Lets the run loop close the undo group, which the UIDocument counts.
        try await waitUntil("the run loop has closed the undo group") { deck.undoManager.groupingLevel == 0 }
        #expect(deck.undoManager.canUndo)
        await deck.close()

        let saved = try DeckFile.decode(FileWrapper(url: url, options: .immediate))
        #expect(saved.cards.map(\.question) == ["dom", "kot", "mysz"])
        #expect(saved.cards[0].answer == "Haus / Heim")
        #expect((saved.cards[0].note, saved.cards[0].kind) == ("dom", .recognition))
        #expect(saved.cards[1].isSuspended)
        #expect(saved.cards[2].hint == "Tier")
        #expect(saved.learningOptions.steps == 3)
        #expect(saved.deletedCards.keys.contains(pies.id))
        #expect(saved.cards[0].contentChanged != nil)
    }

    // MARK: Merging with another device

    /// The iPhone edits while the Mac writes the file: the open document keeps its edit and
    /// takes in the Mac's card and review, and a card of each device is in the file in the end.
    @Test func anEditAndTheOtherDevicesChangeAreMerged() async throws {
        let dom = makeCard("dom", answer: "Haus")
        let original = try Deck(cards: [dom, makeCard("kot", answer: "Katze")])
        let url = try write(original)
        let deck = OpenDeck(url: url)
        let document = try await waitForDocument(of: deck)

        document.add(CardText(question: "mysz", answer: "Maus")!)
        document.editText(of: dom.id, to: CardText(question: "dom", answer: "Heim")!)

        var mac = original
        let ryba = makeCard("ryba", answer: "Fisch")
        _ = mac.apply(try #require(DeckChange.adding([ryba], to: mac)), at: .now.addingTimeInterval(10), calendar: document.calendar)
        try review(dom.id, in: &mac, calendar: document.calendar)
        try await writeUntil(
            "the cards of both devices are in the document", write: { try await writeCoordinated(mac, to: url) },
            until: { document.deck.cards.count == 4 })
        #expect(Set(document.deck.cards.map(\.question)) == ["dom", "kot", "mysz", "ryba"])
        #expect(document.deck.card(withID: dom.id)?.answer == "Heim")
        #expect(document.deck.card(withID: dom.id)?.log.count == 1)
        #expect(deck.document === document)

        await deck.merger.merging?.value
        await deck.close()
        let saved = try DeckFile.decode(FileWrapper(url: url, options: .immediate))
        #expect(Set(saved.cards.map(\.question)) == ["dom", "kot", "mysz", "ryba"])
        #expect(saved.card(withID: dom.id)?.answer == "Heim")
        #expect(saved.card(withID: dom.id)?.log.count == 1)
    }

    /// The Mac deleted a card, and the iPhone reviewed it later: the card stays, with its review.
    @Test func aCardReviewedAfterItsDeletionOnTheOtherDeviceStays() async throws {
        let dom = makeCard("dom", answer: "Haus")
        let kot = makeCard("kot", answer: "Katze")
        let original = try Deck(cards: [dom, kot])
        let url = try write(original)
        let deck = OpenDeck(url: url)
        let document = try await waitForDocument(of: deck)

        var mac = original
        _ = mac.apply(try #require(DeckChange.removing([kot.id], from: mac)), at: .now.addingTimeInterval(-3600), calendar: document.calendar)
        // Later than the deletion: the phone studies the card.
        var mode = try SessionMode.study(StudySession(deck: Deck(cards: [kot]), at: document.clock.now, calendar: document.calendar))
        guard case let .rescheduled(change) = mode.grade(.good, in: document.deck, at: document.clock.now, calendar: document.calendar) else {
            Issue.record("The study session didn't reschedule the card.")
            return
        }
        document.applyReview(change, alongside: UndoCompanion(undo: {}, redo: {}))
        let reviewed = try #require(document.deck.card(withID: kot.id))
        #expect(reviewed.log.count == 1)

        try await writeCoordinated(mac, to: url)
        // Whichever device changed the file last, the reviewed card is in the document.
        try await Task.sleep(for: .milliseconds(500))
        await deck.merger.merging?.value
        #expect(document.deck.card(withID: reviewed.id)?.log.count == 1)
        await deck.close()
        let saved = try DeckFile.decode(FileWrapper(url: url, options: .immediate))
        #expect(saved.card(withID: reviewed.id)?.log.count == 1)
    }

    // MARK: Helpers

    @discardableResult
    private func write(_ deck: Deck, named name: String = "Polish.mnemit") throws -> URL {
        let url = directory.appending(path: name, directoryHint: .isDirectory)
        try DeckFile.fileWrapper(for: deck).write(to: url, options: .atomic, originalContentsURL: nil)
        return url
    }

    /// Reviews the card `id` with Good, as the Mac does.
    private func review(_ id: Card.ID, in deck: inout Deck, calendar: StudyCalendar) throws {
        guard let card = deck.card(withID: id) else { return }
        var mode = try SessionMode.study(StudySession(deck: Deck(cards: [card]), at: .now, calendar: calendar))
        guard case let .rescheduled(change) = mode.grade(.good, in: deck, at: .now, calendar: calendar) else {
            Issue.record("The study session didn't reschedule the card.")
            return
        }
        _ = deck.apply(change, at: .now, calendar: calendar)
    }

    /// Writes `deck` to `url` as another process would, coordinated and off the main thread:
    /// the UIDocument, a file presenter, gives the file up for the write on the main thread.
    private func writeCoordinated(_ deck: Deck, to url: URL) async throws {
        try await Task.detached {
            var coordinationError: NSError?
            var writeError: (any Error)?
            NSFileCoordinator().coordinate(writingItemAt: url, options: .forReplacing, error: &coordinationError) { url in
                do {
                    try DeckFile.fileWrapper(for: deck).write(to: url, options: .atomic, originalContentsURL: nil)
                } catch {
                    writeError = error
                }
            }
            if let coordinationError {
                throw coordinationError
            }
            if let writeError {
                throw writeError
            }
        }.value
    }

    private func waitForDocument(of deck: OpenDeck) async throws -> VocabularyDocument {
        try await waitUntil("the deck is open and can be changed") { deck.document != nil && deck.isEditable }
        return try #require(deck.document)
    }
}
