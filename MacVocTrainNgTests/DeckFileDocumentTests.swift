import AppKit
import Combine
import Foundation
import Testing

@testable import MacVocTrain
@testable import VocabCore

/// Tests of decks held open through NSDocument. They run one at a time: reading and writing the
/// files go through file coordination, and the two suites at once leave it stalled in the test host
/// (measured 26.10.2026: every wait of every test timed out, each suite alone passed in a second).
@Suite(.serialized)
enum DeckFileTests {}

extension DeckFileTests {
    /// The Mac's headless NSDocument that holds an open deck (#285): it reads and saves the file
    /// without a window, reads it again when another process changed it, and its undo manager can
    /// be routed to Edit ▸ Undo by a window of the app. The tests that wait for NSDocument in vain
    /// fail after two minutes instead of holding up the run.
    @MainActor @Suite(.timeLimit(.minutes(3)))
    struct DeckFileDocumentTests {
        let directory: URL

        init() throws {
            directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        // MARK: Reading and saving

        @Test func readsTheDeckWithoutAWindow() async throws {
            let url = try write(Deck(cards: [makeCard("dom")]))
            let file = DeckFileDocument(fileURL: url)
            #expect(NSDocumentController.shared.document(for: url) === file)

            #expect(await open(file))
            #expect(file.takeLoadedDeck()?.cards.map(\.question) == ["dom"])
            // Once.
            #expect(file.takeLoadedDeck() == nil)
            #expect(file.windowControllers.isEmpty)
            #expect(file.undoManager != nil)
            #expect(!file.isClosed)

            await close(file)
            #expect(file.isClosed)
            #expect(NSDocumentController.shared.document(for: url) == nil)
        }

        @Test func aFileThatIsNoDeckFailsAndLeavesNoDocument() async throws {
            let url = directory.appending(path: "Broken.mnemit", directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            let file = DeckFileDocument(fileURL: url)

            #expect(await open(file) == false)
            #expect(file.failure != nil)
            #expect(file.isClosed)
            #expect(file.takeLoadedDeck() == nil)
            #expect(NSDocumentController.shared.document(for: url) == nil)
        }

        @Test func savesTheDeckOfItsDocumentInPlace() async throws {
            let url = try write(Deck(cards: [makeCard("dom")]))
            let file = DeckFileDocument(fileURL: url)
            #expect(await open(file))
            let document = VocabularyDocument(deck: try #require(file.takeLoadedDeck()))
            document.attachUndoManager(file.undoManager)
            file.document = document
            // The undo group stays open: NSDocument hasn't counted the change, and the merger saves anyway (#295).
            let undoManager = try #require(file.undoManager)
            undoManager.groupsByEvent = false
            undoManager.beginUndoGrouping()
            review(document)
            try await file.saveInPlace()
            let saved = try DeckFile.decode(FileWrapper(url: url, options: .immediate))
            #expect(saved.cards.first?.log.map(\.grade) == [.good])
            #expect(!file.isDocumentEdited)
            undoManager.endUndoGrouping()
            await close(file)
        }

        @Test func savingAClosedDocumentFails() async throws {
            let url = try write(Deck(cards: [makeCard("dom")]))
            let file = DeckFileDocument(fileURL: url)
            #expect(await open(file))
            await close(file)
            await #expect(throws: (any Error).self) { try await file.saveInPlace() }
        }

        /// NSDocument counts a change when its undo group closes, and `close` saves it.
        @Test func closingSavesWhatNSDocumentCounted() async throws {
            let url = try write(Deck(cards: [makeCard("dom")]))
            let file = DeckFileDocument(fileURL: url)
            #expect(await open(file))
            let document = VocabularyDocument(deck: try #require(file.takeLoadedDeck()))
            document.attachUndoManager(file.undoManager)
            file.document = document
            edit(document, of: file)
            try await waitUntil("NSDocument counted the change", timeout: .seconds(120)) { file.isDocumentEdited }

            await close(file)
            let saved = try DeckFile.decode(FileWrapper(url: url, options: .immediate))
            #expect(saved.cards.first?.log.map(\.grade) == [.good])
        }

        // MARK: Another process writes the file

        /// What the spike of phase 5 asked: with nothing unsaved NSDocument reads the file again on its own,
        /// without a window, and says so.
        @Test func aForeignWriteIsReadAgain() async throws {
            let dom = makeCard("dom")
            let url = try write(Deck(cards: [dom]))
            let file = DeckFileDocument(fileURL: url)
            #expect(await open(file))
            _ = file.takeLoadedDeck()
            let loads = Loads(file)

            let changed = try Deck(cards: [dom, makeCard("kot")], contentModified: .now)
            try await writeUntil(
                "NSDocument read the file again", write: { try await writeCoordinated(changed, to: url) },
                until: { loads.count > 0 })
            #expect(file.takeLoadedDeck()?.cards.count == 2)
            await close(file)
        }

        /// The second thing the spike asked: a foreign write while the deck has a change NSDocument counted
        /// but has not saved. NSDocument must neither ask the learner, which would block a deck without a
        /// window, nor overwrite the other process's file with its own.
        @Test func aForeignWriteWhileTheDeckIsEditedIsReadAgainWithoutAsking() async throws {
            let dom = makeCard("dom")
            let url = try write(Deck(cards: [dom]))
            let file = DeckFileDocument(fileURL: url)
            #expect(await open(file))
            let document = VocabularyDocument(deck: try #require(file.takeLoadedDeck()))
            document.attachUndoManager(file.undoManager)
            file.document = document
            edit(document, of: file)
            try await waitUntil("NSDocument counted the change", timeout: .seconds(120)) { file.isDocumentEdited }
            let loads = Loads(file)

            let changed = try Deck(cards: [dom, makeCard("kot")], contentModified: .now)
            try await writeUntil(
                "NSDocument read the file again", write: { try await writeCoordinated(changed, to: url) },
                until: { loads.count > 0 })
            let read = try #require(file.takeLoadedDeck())
            #expect(read.cards.count == 2)
            // The document the views show still has the review, which the merger merges into it.
            #expect(document.deck.cards.first?.log.count == 1)
            await close(file)
        }

        // MARK: Undo

        /// Edit ▸ Undo asks the key window for its undo manager; a window of the app answers with the manager of the
        /// deck it shows (`windowWillReturnUndoManager`). NSDocument gets its manager from nowhere else: the deck has
        /// no window of its own. Undo in the one deck leaves the other alone.
        @Test func eachDecksUndoManagerAnswersEditUndoThroughTheWindow() async throws {
            let first = OpenDeck(url: try write(Deck(cards: [makeCard("dom")]), named: "A.mnemit"))
            let second = OpenDeck(url: try write(Deck(cards: [makeCard("kot")]), named: "B.mnemit"))
            let a = try await waitForDocument(of: first)
            let b = try await waitForDocument(of: second)
            for (deck, document) in [(first, a), (second, b)] {
                deck.undoManager.groupsByEvent = false
                step(deck.undoManager) { review(document) }
            }

            let delegate = DeckWindowDelegate()
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 200), styleMask: [.titled], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.delegate = delegate
            window.orderFront(nil)
            defer { window.close() }

            // Today or Progress is selected: the window answers with a manager of its own, no deck's.
            #expect(window.undoManager === delegate.own)

            delegate.selected = first
            #expect(window.undoManager === first.undoManager)
            #expect(window.firstResponder?.undoManager === first.undoManager)
            #expect(try #require(window.firstResponder).tryToPerform(Selector(("undo:")), with: nil))
            #expect(a.deck.cards[0].log.isEmpty)
            #expect(b.deck.cards[0].log.count == 1)

            delegate.selected = second
            #expect(window.undoManager === second.undoManager)
            #expect(try #require(window.firstResponder).tryToPerform(Selector(("undo:")), with: nil))
            #expect(b.deck.cards[0].log.isEmpty)

            // Redo comes back to the deck it was undone in.
            delegate.selected = first
            #expect(try #require(window.firstResponder).tryToPerform(Selector(("redo:")), with: nil))
            #expect(a.deck.cards[0].log.count == 1)
            #expect(b.deck.cards[0].log.isEmpty)
            await first.close()
            await second.close()
        }

        /// The undo steps are NSDocument's: a change that reaches the undo manager makes the deck edited, undoing it
        /// all makes it clean again, and a deck that went through a review can be saved and undone afterwards.
        @Test func undoGoesOnWorkingAfterASave() async throws {
            let deck = OpenDeck(url: try write(Deck(cards: [makeCard("dom")])))
            let document = try await waitForDocument(of: deck)
            deck.undoManager.groupsByEvent = false
            step(deck.undoManager) { review(document) }
            deck.merger.saves.flush()
            await deck.merger.saves.saving?.value
            #expect(deck.undoManager.canUndo)

            deck.undoManager.undo()
            #expect(document.deck.cards[0].log.isEmpty)
            await deck.close()
            let saved = try DeckFile.read(at: deck.url)
            #expect(saved.cards.first?.log.isEmpty == true)
        }

        // MARK: Helpers

        /// Counts the times `file` read the file after it was told to.
        @MainActor
        private final class Loads {
            private(set) var count = 0
            private var observation: AnyCancellable?

            init(_ file: DeckFileDocument) {
                observation = NotificationCenter.default.publisher(for: DeckFileDocument.didLoad, object: file)
                    .receive(on: DispatchQueue.main)
                    .sink { [weak self] _ in self?.count += 1 }
            }
        }

        /// What the app's window will be: it answers for the undo manager of the deck selected. It never answers
        /// nil: a window that got nil once keeps an undo manager of its own and does not ask again.
        @MainActor
        private final class DeckWindowDelegate: NSObject, NSWindowDelegate {
            var selected: OpenDeck?
            let own = UndoManager()

            func windowWillReturnUndoManager(_ window: NSWindow) -> UndoManager? {
                selected?.undoManager ?? own
            }
        }

        /// A change of `document` in one undo group of its own, which NSDocument counts as one edit, as an
        /// event of the app would.
        private func edit(_ document: VocabularyDocument, of file: DeckFileDocument) {
            guard let undoManager = file.undoManager else {
                Issue.record("The document has no undo manager.")
                return
            }
            undoManager.groupsByEvent = false
            step(undoManager) { review(document) }
        }

        private func open(_ file: DeckFileDocument) async -> Bool {
            await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
                file.open(completion: { @Sendable success in continuation.resume(returning: success) })
            }
        }

        private func close(_ file: DeckFileDocument) async {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                file.close(completion: { @Sendable _ in continuation.resume() })
            }
        }

        private func waitForDocument(of deck: OpenDeck) async throws -> VocabularyDocument {
            try await waitUntil("the deck is open and can be changed", timeout: .seconds(120)) { deck.document != nil && deck.isEditable }
            return try #require(deck.document)
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

        private func makeCard(_ question: String) -> Card {
            Card(text: CardText(question: question, answer: "x")!, created: .now.addingTimeInterval(-60))
        }

        @discardableResult
        private func write(_ deck: Deck, named name: String = "Polish.mnemit") throws -> URL {
            let url = directory.appending(path: name, directoryHint: .isDirectory)
            try DeckFile.fileWrapper(for: deck).write(to: url, options: .atomic, originalContentsURL: nil)
            return url
        }

        /// Writes `deck` to `url` as another process would, coordinated and off the main thread: the document,
        /// a file presenter, gives the file up for the write on the main thread, so a coordinated write there
        /// would wait for itself.
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
    }
}
