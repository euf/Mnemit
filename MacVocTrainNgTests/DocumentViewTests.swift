import AppKit
import SwiftUI
import Testing

@testable import MacVocTrain
@testable import VocabCore

extension WindowTests {
    /// The content of a document window in a real window, typed into through the field editor.
    @MainActor
    struct DocumentViewTests {
        let document: VocabularyDocument
        let undoManager: UndoManager
        let window: NSWindow
        private let delegate: DocumentWindowDelegate

        init() throws {
            document = try VocabularyDocument(deck: Deck(cards: [Card(question: "frax", answer: "frox")]))
            // The window hands out the undo manager, as a document window does;
            // `DocumentView` attaches it to the document.
            undoManager = UndoManager()
            delegate = DocumentWindowDelegate(undoManager: undoManager)
            window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 600), styleMask: [.titled], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.delegate = delegate
        }

        /// The window on the card list: a deck opens on its overview.
        private func show(isEditable: Bool) {
            window.contentView = NSHostingView(
                rootView: DocumentView(document: document, fileURL: nil, isEditable: isEditable, merger: VersionMerger { _ in }, initialScreen: .cards))
            window.orderFront(nil)
            window.contentView?.layoutSubtreeIfNeeded()
        }

        /// The view attaches the undo manager of the window to the document, which can be changed from then on
        /// (#305): the Add Cards sheet and the table's edits register their undo steps with it.
        @Test(arguments: [true, false])
        func theViewAttachesTheUndoManagerOfTheWindow(isEditable: Bool) async throws {
            defer { window.close() }
            #expect(!document.isReadyToEdit)
            show(isEditable: isEditable)
            try await waitUntil("the view attaches the undo manager") { document.undoManager === undoManager }
            #expect(document.isReadyToEdit)
        }

        /// File ▸ New makes a deck that starts with New words and is asked about once: Cancel of its window's
        /// New Deck sheet leaves that mark. A document that was opened is never asked about.
        @Test func aNewDeckIsAskedAboutOnce() {
            let made = NewDecks.newDocument()
            #expect(made.deck.learningOptions.introducesNewCards)
            #expect(NewDecks.take(made))
            #expect(!NewDecks.take(made))
            #expect(!NewDecks.take(document))
        }
    }
}
