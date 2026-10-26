import AppKit
import SwiftUI
import Testing

@testable import MacVocTrain
@testable import VocabCore

extension WindowTests {
    /// The study stream's screen in a real window, driven by the keys it binds.
    @MainActor
    struct SessionViewTests {
        let document: VocabularyDocument
        let undoManager: UndoManager
        let model: SessionViewModel
        let window: NSWindow
        private let delegate: DocumentWindowDelegate

        init() throws {
            document = try VocabularyDocument(deck: Deck(cards: [Card(question: "blim", answer: "blom"), Card(question: "frax", answer: "frox")]))
            // The window has no `DocumentView` to give the document its undo manager.
            undoManager = makeUndoManager(for: document)
            model = SessionViewModel(document: document)
            delegate = DocumentWindowDelegate(undoManager: undoManager)
            window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 800, height: 600), styleMask: [.titled], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.delegate = delegate
            window.contentView = NSHostingView(rootView: SessionView(model: model, ring: DailyRingModel(), onClose: {}))
            window.orderFront(nil)
        }

        /// Presses `characters` with `modifiers` in the window the way AppKit offers a key to the
        /// buttons' shortcuts, as a key equivalent. Returns whether a button took it.
        private func press(_ characters: String, keyCode: UInt16, modifiers: NSEvent.ModifierFlags = []) throws -> Bool {
            let event = try #require(
                NSEvent.keyEvent(
                    with: .keyDown, location: .zero, modifierFlags: modifiers, timestamp: ProcessInfo.processInfo.systemUptime,
                    windowNumber: window.windowNumber, context: nil, characters: characters, charactersIgnoringModifiers: characters,
                    isARepeat: false, keyCode: keyCode
                )
            )
            return window.performKeyEquivalent(with: event)
        }

        /// Waits until the stream's keys are in the window, then presses `characters`.
        private func pressWhenReady(_ characters: String, keyCode: UInt16, modifiers: NSEvent.ModifierFlags = []) async throws {
            var taken = false
            try await waitUntil("a button takes the key") {
                taken = (try? press(characters, keyCode: keyCode, modifiers: modifiers)) ?? false
                return taken
            }
        }

        /// Takes the screen down while the model is alive: closing alone leaves the views to disappear when the
        /// window is released, after the test, with the model gone.
        private func close() {
            window.contentView = nil
            window.close()
        }

        /// Opens the sheet that edits the card being asked and returns it once it shows
        /// `fieldCount` fields.
        private func showEditSheet(fieldCount: Int) async throws -> NSWindow {
            try await pressWhenReady("e", keyCode: 14, modifiers: .command)
            try await waitUntil("the sheet is shown") { window.attachedSheet != nil }
            let sheet = try #require(window.attachedSheet)
            try await waitUntil("the sheet shows \(fieldCount) fields") { editableFields(in: sheet).count == fieldCount }
            return sheet
        }

        /// The fields of the sheet, top to bottom.
        private func editableFields(in sheet: NSWindow) -> [NSTextField] {
            let fields = sheet.contentView.map { descendants(of: $0).compactMap { $0 as? NSTextField }.filter(\.isEditable) } ?? []
            return fields.sorted { $0.convert($0.bounds, to: nil).maxY > $1.convert($1.bounds, to: nil).maxY }
        }

        private func descendants(of view: NSView) -> [NSView] {
            view.subviews.flatMap { [$0] + descendants(of: $0) }
        }

        /// Before the answer is shown, the sheet shows question and hint but not the
        /// answer (#289).
        @Test func editingWhileAskingHidesTheAnswer() async throws {
            defer { close() }
            let card = try #require(model.currentCard)

            let sheet = try await showEditSheet(fieldCount: 2)
            #expect(editableFields(in: sheet).map(\.stringValue) == [card.question, card.hint])
            window.endSheet(sheet)
        }

        /// Once the answer is shown, the sheet edits it too (#289).
        @Test func editingTheShownAnswer() async throws {
            defer { close() }
            let card = try #require(model.currentCard)
            model.reveal()

            // Question, answer, hint and word key.
            let sheet = try await showEditSheet(fieldCount: 4)
            #expect(editableFields(in: sheet).contains { $0.stringValue == card.answer })
            window.endSheet(sheet)
        }

        /// Space shows the answer. The arrow keys grade like the swipes, see `GradeSwipeTests`; a window that
        /// plays the card's flight out crashes the test host in `ActivityRing`'s canvas (found in phase 3a).
        @Test func spaceShowsTheAnswer() async throws {
            defer { close() }
            #expect(model.stage == .asking)
            try await pressWhenReady(" ", keyCode: 49)
            #expect(model.stage == .revealed)
        }

        /// ⌘Z takes back the review: the stream's own key goes ahead of Edit ▸ Undo.
        @Test func commandZAfterAGradeTakesBackTheReview() async throws {
            defer { close() }
            let first = try #require(model.currentCard)
            model.reveal()
            undoManager.beginUndoGrouping()
            model.grade(.good)
            undoManager.endUndoGrouping()
            #expect(document.card(withID: first.id)?.log.count == 1)
            #expect(model.currentCard?.id != first.id)

            try await pressWhenReady("z", keyCode: 6, modifiers: .command)
            try await waitUntil("the review is taken back") { model.currentCard?.id == first.id }
            #expect(document.card(withID: first.id)?.log.isEmpty == true)
        }
    }
}
