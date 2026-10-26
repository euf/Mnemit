import Foundation
import Testing

@testable import MacVocTrain
@testable import VocabCore

extension DeckFileTests {
    /// Opening, saving and reading again a deck with the Mac's headless NSDocument (#285), the tests
    /// of the iPhone's `OpenDeckTests` for the Mac. A test that waits for the document in vain fails
    /// after two minutes, see `waitFor`, instead of holding up the run.
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

        /// A deck of MacVocTrain NG, `.voctrain`, opens like one of Mnemit and is saved in place
        /// under its name: nothing is renamed.
        @Test func aVoctrainDeckOpensAndIsSavedUnderItsName() async throws {
            let folder = directory.appending(path: "Mnemit", directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let legacy = try write(Deck(cards: [makeCard("dom")]), named: "Greek A1–A2.voctrain", in: folder)
            try write(Deck(cards: [makeCard("kot")]), named: "Greek B1.mnemit", in: folder)

            let deck = OpenDeck(url: legacy)
            let document = try await waitForDocument(of: deck)
            #expect(document.deck.cards.map(\.question) == ["dom"])

            edit(document, of: deck)
            await deck.close()
            let saved = try DeckFile.decode(FileWrapper(url: legacy, options: .immediate))
            #expect(saved.cards.first?.log.map(\.grade) == [.good])
            #expect(try FileManager.default.contentsOfDirectory(atPath: folder.path).sorted() == ["Greek A1–A2.voctrain", "Greek B1.mnemit"])
        }

        @Test func aFileThatIsNoDeckFails() async throws {
            let url = directory.appending(path: "Broken.mnemit", directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            let deck = OpenDeck(url: url)

            try await waitFor("the deck reports why it failed") { deck.failure != nil }
            #expect(deck.document == nil)
            await deck.close()
        }

        /// NSDocument counts the review through its undo manager and saves it when
        /// the deck closes.
        @Test func closingSavesAReview() async throws {
            let url = try write(Deck(cards: [makeCard("dom")]))
            let deck = OpenDeck(url: url)
            let document = try await waitForDocument(of: deck)
            // Attached before the document shows (#305).
            #expect(document.undoManager === deck.undoManager)
            #expect(document.isReadyToEdit)

            edit(document, of: deck)
            await deck.close()

            let saved = try DeckFile.decode(FileWrapper(url: url, options: .immediate))
            #expect(saved.cards.first?.log.map(\.grade) == [.good])
        }

        /// The merger saves through the deck's NSDocument, even a change NSDocument
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

        // MARK: Registry

        /// The registry keeps one deck per file however its URL is spelled, keeps it open until it is closed,
        /// and lists the documents of the decks that are read.
        @Test func theRegistryKeepsOneDeckPerFile() async throws {
            let registry = OpenDecks()
            let url = try write(Deck(cards: [makeCard("dom")]))
            let spelled = directory.appending(path: "x/../Polish.mnemit", directoryHint: .isDirectory)

            let deck = registry.open(url)
            #expect(registry.open(spelled) === deck)
            #expect(registry.deck(for: url) === deck)
            let document = try await waitForDocument(of: deck)
            #expect(registry.documents.map { $0 === document } == [true])

            await registry.close(url)
            #expect(registry.deck(for: url) == nil)
            #expect(registry.documents.isEmpty)
            #expect(deck.undoManager.groupingLevel == 0)
            #expect(registry.open(url) !== deck)
            await registry.closeAll()
            #expect(registry.documents.isEmpty)
        }

        /// Opening many decks at once, as a study run over every deck of a folder does: all are read, and
        /// closing saves what each holds.
        @Test func fiftyDecksOpenAtOnceAndSaveOnClose() async throws {
            let registry = OpenDecks()
            let urls = try (0..<50).map { try write(Deck(cards: [makeCard("dom \($0)")]), named: "Deck \($0).mnemit") }
            let decks = urls.map { registry.open($0) }
            for deck in decks {
                _ = try await waitForDocument(of: deck)
            }
            #expect(registry.documents.count == 50)
            let reviewed = try #require(decks.last)
            edit(try #require(reviewed.document), of: reviewed)

            await registry.closeAll()
            let saved = try DeckFile.read(at: urls[49])
            #expect(saved.cards.first?.log.map(\.grade) == [.good])
            #expect(try DeckFile.read(at: urls[0]).cards.first?.log.isEmpty == true)
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

        /// A save by NSDocument writes the package of the deck again from its snapshot, which has to
        /// carry the media: a review of a card must not cost the deck its pictures.
        @Test func aDeckKeepsItsMediaWhenTheDocumentSavesIt() async throws {
            let data = Data("a picture".utf8)
            let (original, name) = try deckWithMedia(data)
            let url = try write(original)
            let deck = OpenDeck(url: url)
            let document = try await waitForDocument(of: deck)
            #expect(document.deck.media.contents(of: name) == data)

            edit(document, of: deck)
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
            edit(document, of: deck)
            await deck.close()
            let saved = try DeckFile.read(at: url)
            #expect(saved.cards.count == 2)
            #expect(saved.media.contents(of: name) == data)
        }

        /// A review in one undo group of its own, which NSDocument counts as one edit, as an event of the app
        /// would: the tests have no event loop that closes the group.
        private func edit(_ document: VocabularyDocument, of deck: OpenDeck) {
            deck.undoManager.groupsByEvent = false
            step(deck.undoManager) { review(document) }
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
        /// thread: the NSDocument, a file presenter, gives the file up for the write on the
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

        /// `waitUntil` with the generous deadline of these tests: they wait for NSDocument and the merge after
        /// it, which need the main actor, and other tests keep it busy for seconds at a time.
        private func waitFor(_ comment: Comment, sourceLocation: SourceLocation = #_sourceLocation, _ condition: () -> Bool) async throws {
            try await waitUntil(comment, timeout: .seconds(120), sourceLocation: sourceLocation, condition)
        }

        private func waitForDocument(of deck: OpenDeck) async throws -> VocabularyDocument {
            try await waitFor("the deck is open and can be changed") { deck.document != nil && deck.isEditable }
            return try #require(deck.document)
        }
    }
}
