import Foundation
import Testing
import UniformTypeIdentifiers

@testable import VocTrain
@testable import VocabCore

/// Opening, saving and reading again a deck with the app's own UIDocument (#285).
/// A test that waits for the UIDocument in vain fails after two minutes, see `waitUntil`,
/// instead of holding up the run.
@MainActor @Suite(.timeLimit(.minutes(3)))
struct OpenDeckTests {
    let directory: URL

    init() throws {
        directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    @Test func opensTheDeckOfItsFile() async throws {
        let url = try write(Deck(cards: [makeCard("dom")]))
        let deck = OpenDeck(url: url)

        let document = try await waitForDocument(of: deck)
        #expect(document.deck.cards.map(\.question) == ["dom"])
        #expect(deck.isEditable)
        await deck.close()
    }

    /// A deck of MacVocTrain NG, `.voctrain`, is listed next to one of Mnemit, opens like
    /// it and is saved in place under its name: nothing is renamed.
    @Test func aVoctrainDeckOpensAndIsListedNextToAMnemitOne() async throws {
        let folder = directory.appending(path: "Mnemit", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let legacy = try write(Deck(cards: [makeCard("dom")]), named: "Greek A1–A2.voctrain", in: folder)
        try write(Deck(cards: [makeCard("kot")]), named: "Greek B1.mnemit", in: folder)

        #expect(KnownDecks.decks(in: folder).map(\.name).sorted() == ["Greek A1–A2", "Greek B1"])
        #expect(KnownDecks.decks(in: folder).allSatisfy { $0.url.isDeck })
        let deck = OpenDeck(url: legacy)
        let document = try await waitForDocument(of: deck)
        #expect(document.deck.cards.map(\.question) == ["dom"])

        review(document)
        // Lets the run loop close the undo group, which the UIDocument counts.
        try await waitUntil("the run loop has closed the undo group") { deck.undoManager.groupingLevel == 0 }
        await deck.close()
        let saved = try DeckFile.decode(FileWrapper(url: legacy, options: .immediate))
        #expect(saved.cards.first?.log.map(\.grade) == [.good])
        #expect(try FileManager.default.contentsOfDirectory(atPath: folder.path).sorted() == ["Greek A1–A2.voctrain", "Greek B1.mnemit"])

        // The Info.plist declares the same types as document types, and the Anki packages after them.
        let documentTypes = Bundle.main.infoDictionary?["CFBundleDocumentTypes"] as? [[String: Any]] ?? []
        #expect(documentTypes.flatMap { $0["LSItemContentTypes"] as? [String] ?? [] } == (UTType.deckTypes + UTType.ankiPackages).map(\.identifier))
    }

    @Test func aFileThatIsNoDeckFails() async throws {
        let url = directory.appending(path: "Broken.mnemit", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let deck = OpenDeck(url: url)

        try await waitUntil("the deck reports why it failed") { deck.failure != nil }
        #expect(deck.document == nil)
        await deck.close()
    }

    /// The UIDocument counts the review through its undo manager and saves it when
    /// the deck closes.
    @Test func closingSavesAReview() async throws {
        let url = try write(Deck(cards: [makeCard("dom")]))
        let deck = OpenDeck(url: url)
        let document = try await waitForDocument(of: deck)
        // Attached before the document shows (#305).
        #expect(document.undoManager === deck.undoManager)
        #expect(document.isReadyToEdit)

        review(document)
        // Lets the run loop close the undo group, which the UIDocument counts.
        try await waitUntil("the run loop has closed the undo group") { deck.undoManager.groupingLevel == 0 }
        await deck.close()

        let saved = try DeckFile.decode(FileWrapper(url: url, options: .immediate))
        #expect(saved.cards.first?.log.map(\.grade) == [.good])
    }

    /// The merger saves through the deck's UIDocument, even a change the UIDocument
    /// hasn't counted (#295): here the change registers with an undo manager of its own.
    @Test func theMergerSavesThroughTheDeckFile() async throws {
        let url = try write(Deck(cards: [makeCard("dom")]))
        let deck = OpenDeck(url: url)
        let document = try await waitForDocument(of: deck)
        let undoManager = UndoManager()
        undoManager.groupsByEvent = false
        document.attachUndoManager(undoManager)
        deck.merger.attach(document, fileURL: url, isEditable: true)
        await deck.merger.merging?.value

        undoManager.beginUndoGrouping()
        review(document)
        undoManager.endUndoGrouping()
        // Saves the change at once instead of after a few seconds.
        deck.merger.suspend()
        await deck.merger.saves.saving?.value

        let saved = try DeckFile.decode(FileWrapper(url: url, options: .immediate))
        #expect(saved.cards.first?.log.map(\.grade) == [.good])
        await deck.close()
    }

    /// Another device's change to the file is merged into the open document (#296).
    @Test func aChangedFileIsMergedIntoTheOpenDocument() async throws {
        let dom = makeCard("dom")
        let url = try write(Deck(cards: [dom]))
        let deck = OpenDeck(url: url)
        let document = try await waitForDocument(of: deck)

        let changed = try Deck(cards: [dom, makeCard("kot")], contentModified: .now)
        try await writeUntil(
            "the card of the other device is in the document", write: { try await writeCoordinated(changed, to: url) },
            until: { document.deck.cards.count == 2 })
        #expect(document.deck.cards.count == 2)
        #expect(deck.document === document)
        await deck.close()
    }

    /// A study session goes on when the Mac changes the file (#296): the deck gets the
    /// Mac's reviews, and the session skips a card the Mac suspended.
    @Test func aStudySessionGoesOnWhenTheFileChanges() async throws {
        let original = try Deck(cards: ["dom", "kot", "pies"].map(makeCard))
        let url = try write(original)
        let deck = OpenDeck(url: url)
        let document = try await waitForDocument(of: deck)
        let model = StudyModel(document: document)
        let asked = try #require(model.currentCard?.id)

        // The Mac reviews one of the cards not asked yet and suspends the other.
        var mac = original
        let notAsked = mac.cards.map(\.id).filter { $0 != asked }
        try review(notAsked[0], in: &mac, calendar: document.calendar)
        let suspension = try #require(DeckChange.settingSuspended(true, of: [notAsked[1]], in: mac, at: .now))
        _ = mac.apply(suspension, at: .now, calendar: document.calendar)
        try await writeUntil(
            "the card the Mac suspended is suspended in the document", write: { try await writeCoordinated(mac, to: url) },
            until: { document.deck.card(withID: notAsked[1])?.isSuspended == true })
        #expect(deck.document === document)
        #expect(document.deck.card(withID: notAsked[1])?.isSuspended == true)
        #expect(document.deck.card(withID: notAsked[0])?.log.count == 1)
        #expect(model.currentCard?.id == asked)

        model.reveal()
        model.grade(.good)
        #expect(model.currentCard?.id == notAsked[0])
        await deck.close()
    }

    // MARK: Media

    /// The package of a deck with one card that names `data` as its question image.
    private func deckWithMedia(_ data: Data) throws -> (deck: Deck, name: String) {
        var media = DeckMedia()
        let name = media.add(data, fileExtension: "png")
        var card = makeCard("dom")
        card.media = CardMedia(questionImage: name)
        return (try Deck(cards: [card], media: media), name)
    }

    /// A save by the UIDocument writes the package of the deck again from its snapshot, which has to
    /// carry the media: a review of a card must not cost the deck its pictures.
    @Test func aDeckKeepsItsMediaWhenTheUIDocumentSavesIt() async throws {
        let data = Data("a picture".utf8)
        let (original, name) = try deckWithMedia(data)
        let url = try write(original)
        let deck = OpenDeck(url: url)
        let document = try await waitForDocument(of: deck)
        #expect(document.deck.media.contents(of: name) == data)

        review(document)
        try await waitUntil("the run loop has closed the undo group") { deck.undoManager.groupingLevel == 0 }
        await deck.close()

        let saved = try DeckFile.read(at: url)
        #expect(saved.cards.first?.log.map(\.grade) == [.good])
        #expect(saved.cards.first?.questionImage == name)
        #expect(saved.media.contents(of: name) == data)
        #expect(try FileManager.default.contentsOfDirectory(atPath: url.appending(path: "media").path) == [name])
    }

    /// The file of a card that came from another device comes with the card, through the merge.
    @Test func theMediaOfTheOtherDevicesCardsComeThroughTheMerge() async throws {
        let data = Data("a picture from the Mac".utf8)
        let dom = makeCard("dom")
        let url = try write(Deck(cards: [dom]))
        let deck = OpenDeck(url: url)
        let document = try await waitForDocument(of: deck)

        var media = DeckMedia()
        let name = media.add(data, fileExtension: "png")
        var kot = makeCard("kot")
        kot.media = CardMedia(answerImage: name)
        let changed = try Deck(cards: [dom, kot], contentModified: .now, media: media)
        try await writeUntil(
            "the card of the other device and its file are in the document", write: { try await writeCoordinated(changed, to: url) },
            until: { document.deck.cards.count == 2 && document.deck.media.contains(name) })
        #expect(document.deck.media.contents(of: name) == data)
        #expect(document.deck.cards.last?.answerImage == name)

        // Saved with the next change: both files and both cards are in the package.
        review(document)
        try await waitUntil("the run loop has closed the undo group") { deck.undoManager.groupingLevel == 0 }
        await deck.close()
        let saved = try DeckFile.read(at: url)
        #expect(saved.cards.count == 2)
        #expect(saved.media.contents(of: name) == data)
    }

    // MARK: A deck edited in place while the app runs

    /// What `Tools/deck-from-tsv` and the other device do to the file under a running app: the tests write
    /// the open deck with a change, as another process does, and look at the document and at the study
    /// stream that asks its cards.
    /// Runs `action` in an undo group of its own, like one event in the app.
    private func step(_ undoManager: UndoManager, _ action: () -> Void) {
        undoManager.beginUndoGrouping()
        action()
        undoManager.endUndoGrouping()
    }

    private struct Running {
        let url: URL
        let deck: OpenDeck
        let document: VocabularyDocument
        let model: StudyModel
    }

    private func openAndStudy(_ questions: [String]) async throws -> Running {
        let url = try write(Deck(cards: questions.map(makeCard)))
        let deck = OpenDeck(url: url)
        let document = try await waitForDocument(of: deck)
        deck.undoManager.groupsByEvent = false
        return Running(url: url, deck: deck, document: document, model: StudyModel(document: document))
    }

    /// Grades the card asked, as the learner does, in one undo group.
    private func grade(_ grade: Grade, in running: Running) {
        step(running.deck.undoManager) {
            running.model.reveal()
            running.model.grade(grade)
        }
    }

    /// The open deck as another device left it after `change`: a moment later, so its changes count as newer.
    private func fileAfter(_ running: Running, _ change: (inout Deck) throws -> DeckChange?) throws -> Deck {
        var other = running.document.deck
        let change = try #require(try change(&other))
        _ = other.apply(change, at: .now.addingTimeInterval(5), calendar: running.document.calendar)
        return other
    }

    /// Whether both cards hold the same progress: the file keeps times to the second, so a card that
    /// came through it differs from the one in memory in the fractions.
    private func sameProgress(_ card: Card?, _ other: Card?) -> Bool {
        guard let card, let other, card.log.count == other.log.count else { return false }
        let sameLog = zip(card.log, other.log).allSatisfy { $0.grade == $1.grade && abs($0.date.timeIntervalSince($1.date)) < 1 }
        guard let state = card.learningState, let otherState = other.learningState else {
            return sameLog && card.learningState == nil && other.learningState == nil
        }
        return sameLog && state.phase == otherState.phase && state.step == otherState.step && state.reviews == otherState.reviews
            && state.lapses == otherState.lapses && abs(state.due.timeIntervalSince(otherState.due)) < 1
            && abs(state.stability - otherState.stability) < 0.001
    }

    private func writeAndWait(_ deck: Deck, to running: Running, until condition: () -> Bool) async throws {
        try await writeUntil("the document has what the file holds", write: { try await writeCoordinated(deck, to: running.url) }, until: condition)
    }

    /// Cards added in the file arrive in the document as new cards and in today's plan, within the allowance.
    @Test func cardsAddedInTheFileAreNewAndInTheDaysPlanWithinTheAllowance() async throws {
        let running = try await openAndStudy(["dom"])
        let document = running.document
        document.newCardAllowance = 2
        let other = try fileAfter(running) { DeckChange.adding(["kot", "pies", "ryba"].map(makeCard), to: $0) }
        try await writeAndWait(other, to: running) { document.deck.cards.count == 4 }

        #expect(Set(document.deck.cards.map(\.id)) == Set(other.cards.map(\.id)))
        let allNew = document.deck.cards.allSatisfy { $0.isNew }
        #expect(allNew)
        #expect(document.dueCards.count == 2)
        let stream = StudyStream(deck: document.deck, at: document.clock.now, calendar: document.calendar, newCardAllowance: 2)
        #expect(stream.session.remainingCount == 2)
        await running.deck.close()
    }

    /// Texts edited in the file: the cards kept keep their progress, and the card on screen and the cards
    /// still to come show the new text.
    @Test func textsEditedInTheFileKeepTheProgressAndShowInTheStream() async throws {
        let running = try await openAndStudy(["dom", "kot", "pies"])
        let document = running.document
        let model = running.model
        let first = try #require(model.currentCard?.id)
        grade(.good, in: running)
        let graded = try #require(document.card(withID: first))
        #expect(graded.log.count == 1)
        let asked = try #require(model.currentCard?.id)
        let last = try #require(document.deck.cards.map(\.id).first { $0 != first && $0 != asked })

        var other = document.deck
        for id in [first, asked, last] {
            let card = try #require(other.card(withID: id))
            let text = CardText(question: card.question, answer: card.answer + " (edited)")!
            _ = other.apply(try #require(DeckChange.editingText(of: id, to: text, in: other)), at: .now.addingTimeInterval(5), calendar: document.calendar)
        }
        try await writeAndWait(other, to: running) { document.card(withID: last)?.answer.hasSuffix("(edited)") == true }

        let kept = try #require(document.card(withID: first))
        #expect(kept.answer.hasSuffix("(edited)"))
        #expect(sameProgress(kept, graded))
        #expect(model.currentCard?.id == asked)
        #expect(model.currentCard?.answer.hasSuffix("(edited)") == true)
        grade(.good, in: running)
        // The next card is the one graded first, due again, or the last: the text of both is new.
        #expect(model.currentCard.map { [first, last].contains($0.id) } == true)
        #expect(model.currentCard?.answer.hasSuffix("(edited)") == true)
        await running.deck.close()
    }

    /// Cards deleted on the other device leave the document, the plan and the stream, also the one on screen:
    /// the stream moves on without a grade. The reviews of a deleted card stay, and the ring does not jump back.
    @Test func cardsDeletedInTheFileLeaveTheStreamAndKeepTheirReviews() async throws {
        let running = try await openAndStudy(["dom", "kot", "pies", "ryba"])
        let document = running.document
        let model = running.model
        let done = try #require(model.currentCard?.id)
        grade(.easy, in: running)
        let asked = try #require(model.currentCard?.id)
        let ringBefore = document.deck.doneCards(onDayOf: document.clock.now, calendar: document.calendar)
        #expect(ringBefore == 1)
        let reviewed = try #require(document.card(withID: done))

        let other = try fileAfter(running) { DeckChange.removing([done, asked], from: $0) }
        try await writeAndWait(other, to: running) { document.deck.card(withID: asked) == nil }

        #expect(document.deck.cards.count == 2)
        #expect(document.card(withID: done) == nil)
        #expect(document.deck.retiredCards.map(\.id) == [done])
        #expect(sameProgress(document.deck.retiredCards.first, reviewed))
        #expect(document.deck.doneCards(onDayOf: document.clock.now, calendar: document.calendar) == ringBefore)
        let noneGraded = document.deck.cards.allSatisfy { $0.log.isEmpty }
        #expect(noneGraded)
        let next = try #require(model.currentCard)
        #expect(next.id != asked && next.id != done)
        #expect(model.stage == .asking)
        #expect(StudySession.counts(for: document.deck, at: document.clock.now, calendar: document.calendar, newCardAllowance: nil).total == 2)
        await running.deck.close()
    }

    /// The same in the app: a card deleted while it is on screen takes no grade, the stream asks the next one.
    @Test func aCardDeletedInTheAppWhileOnScreenIsNotAsked() async throws {
        let running = try await openAndStudy(["dom", "kot", "pies"])
        let document = running.document
        let model = running.model
        let done = try #require(model.currentCard?.id)
        grade(.easy, in: running)
        let asked = try #require(model.currentCard?.id)

        step(running.deck.undoManager) { document.delete([asked, done]) }

        #expect(document.deck.cards.count == 1)
        #expect(document.deck.retiredCards.map(\.id) == [done])
        #expect(document.deck.doneCards(onDayOf: document.clock.now, calendar: document.calendar) == 1)
        let next = try #require(model.currentCard)
        #expect(next.id != asked && next.id != done)
        let noneGraded = document.deck.cards.allSatisfy { $0.log.isEmpty }
        #expect(noneGraded)

        // Undo brings the cards back and takes them out of the retired ones.
        running.deck.undoManager.undo()
        #expect(document.deck.cards.count == 3)
        #expect(document.deck.retiredCards.isEmpty)
        await running.deck.close()
    }

    /// Cards that `deck-from-tsv --suspend-missing` suspends leave the plan and the stream, also the one on
    /// screen, and keep their progress.
    @Test func cardsSuspendedInTheFileLeaveThePlanAndTheStreamAndKeepTheirProgress() async throws {
        let running = try await openAndStudy(["dom", "kot", "pies", "ryba"])
        let document = running.document
        let model = running.model
        let first = try #require(model.currentCard?.id)
        grade(.good, in: running)
        let asked = try #require(model.currentCard?.id)
        let reviewed = try #require(document.card(withID: first))

        let other = try fileAfter(running) { DeckChange.settingSuspended(true, of: [first, asked], in: $0, at: .now) }
        try await writeAndWait(other, to: running) { document.card(withID: asked)?.isSuspended == true }

        #expect(document.card(withID: first)?.isSuspended == true)
        #expect(sameProgress(document.card(withID: first), reviewed))
        #expect(document.deck.cards.count == 4)
        let next = try #require(model.currentCard)
        #expect(next.id != asked && next.id != first)
        #expect(document.deck.cards.filter { !$0.isSuspended }.contains { $0.id == next.id })
        #expect(StudySession.counts(for: document.deck, at: document.clock.now, calendar: document.calendar, newCardAllowance: nil).total == 2)
        let stream = StudyStream(deck: document.deck, at: document.clock.now, calendar: document.calendar)
        #expect(stream.session.remainingCount == 2)
        #expect(stream.session.currentCardID != first && stream.session.currentCardID != asked)
        await running.deck.close()
    }

    /// Undo survives a reread: the grade is undone and its card is in the stream again. The merge of the file
    /// and the edit before it stay, and are not on the undo stack any more.
    @Test func undoTakesBackAGradeAfterTheFileWasMergedAndNothingElse() async throws {
        let running = try await openAndStudy(["dom", "kot", "pies"])
        let document = running.document
        let model = running.model
        let undoManager = running.deck.undoManager
        step(undoManager) { document.add(CardText(question: "wilk", answer: "Wolf")!) }
        let first = try #require(model.currentCard?.id)
        let before = try #require(document.card(withID: first))
        grade(.good, in: running)
        #expect(model.canUndo)

        let added = makeCard("ryba")
        let other = try fileAfter(running) { DeckChange.adding([added], to: $0) }
        try await writeAndWait(other, to: running) { document.card(withID: added.id) != nil }
        #expect(model.canUndo)

        model.undoLast()

        #expect(sameProgress(document.card(withID: first), before))
        #expect(model.currentCard?.id == first)
        #expect(document.card(withID: added.id) != nil)
        #expect(document.deck.cards.count == 5)
        #expect(!undoManager.canUndo)
        await running.deck.close()
    }

    /// The merge deleted the graded card: undo has no card to bring back and leaves the deck as the merge made it.
    @Test func undoAfterAMergedDeletionOfTheGradedCardDoesNothingHarmful() async throws {
        let running = try await openAndStudy(["dom", "kot", "pies"])
        let document = running.document
        let model = running.model
        let first = try #require(model.currentCard?.id)
        grade(.good, in: running)
        let asked = try #require(model.currentCard?.id)

        let other = try fileAfter(running) { DeckChange.removing([first], from: $0) }
        try await writeAndWait(other, to: running) { document.card(withID: first) == nil }
        #expect(document.deck.retiredCards.map(\.id) == [first])

        model.undoLast()

        #expect(document.card(withID: first) == nil)
        #expect(document.deck.cards.count == 2)
        #expect(model.currentCard?.id != first)
        #expect(model.currentCard != nil)
        #expect(asked != first)
        await running.deck.close()
    }

    /// Reviews the first card due with Good, as a study session does.
    private func review(_ document: VocabularyDocument) {
        var mode = SessionMode.study(StudySession(deck: document.deck, at: document.clock.now, calendar: document.calendar))
        guard case let .rescheduled(change) = mode.grade(.good, in: document.deck, at: document.clock.now, calendar: document.calendar) else {
            Issue.record("The study session didn't reschedule the card.")
            return
        }
        document.applyReview(change, alongside: UndoCompanion(undo: {}, redo: {}))
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

    private func makeCard(_ question: String) -> Card {
        Card(text: CardText(question: question, answer: "x")!, created: .now.addingTimeInterval(-60))
    }

    @discardableResult
    private func write(_ deck: Deck, named name: String = "Polish.mnemit", in folder: URL? = nil) throws -> URL {
        let url = (folder ?? directory).appending(path: name, directoryHint: .isDirectory)
        try DeckFile.fileWrapper(for: deck).write(to: url, options: .atomic, originalContentsURL: nil)
        return url
    }

    /// Writes `deck` to `url` as another process would, coordinated and off the main
    /// thread: the UIDocument, a file presenter, gives the file up for the write on the
    /// main thread, so a coordinated write there would wait for itself.
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
