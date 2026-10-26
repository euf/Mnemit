import AppKit
import SwiftUI
import Testing

@testable import MacVocTrain
@testable import VocabCore

/// A window that reports itself as key. A test host that isn't active, such as one
/// started from a terminal, can't activate itself, so no window of it becomes key for real;
/// the tests' `init` then calls `becomeKey()`.
private final class KeyWindow: NSWindow {
    override var isKeyWindow: Bool { true }
}

/// The card list under a text field of its own, which the focus can be in before the table gets it: the
/// card list has no field to type into, the search field is in the window's toolbar.
private struct ListWithField: View {
    var document: VocabularyDocument
    @State private var text = ""

    var body: some View {
        VStack(spacing: 0) {
            TextField("Other field", text: $text)
                .padding(12)
            CardListView(document: document, isEditable: true)
        }
    }
}

extension WindowTests {
    /// The card list in a real window, sorted through its `NSTableView` and clicked into with
    /// synthetic mouse events.
    @MainActor
    struct CardListViewTests {
        let document: VocabularyDocument
        let undoManager: UndoManager
        let window: NSWindow

        init() throws {
            document = try VocabularyDocument(
                deck: Deck(cards: [Card(question: "frax", answer: "frox"), Card(question: "blim", answer: "blom"), Card(question: "glim", answer: "glom")])
            )
            undoManager = makeUndoManager(for: document)
            window = KeyWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 600), styleMask: [.titled], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: ListWithField(document: document))
            // Key for real where the test host is active, as in CI. Another window, such
            // as the open panel of the document app, may be key there.
            window.makeKeyAndOrderFront(nil)
            // In a host that isn't active no window becomes key, and AppKit takes the first click
            // into a window that isn't key only to make it key, whatever `isKeyWindow` says. Tell
            // the window that it is, as AppKit does when the app activates: the app stays inactive.
            if NSApp.keyWindow !== window { window.becomeKey() }
        }

        /// The table of the list; a new sort order replaces it with a new one.
        private var tableView: NSTableView? {
            window.contentView.flatMap { descendants(of: $0).lazy.compactMap { $0 as? NSTableView }.first }
        }

        /// The text field above the table (`ListWithField`), standing in for the toolbar's search field: the leftmost editable one.
        private var otherField: NSTextField? {
            window.contentView.flatMap { contentView in
                descendants(of: contentView)
                    .compactMap { $0 as? NSTextField }
                    .filter(\.isEditable)
                    .min { $0.convert($0.bounds, to: nil).minX < $1.convert($1.bounds, to: nil).minX }
            }
        }

        /// The text field being edited, if any.
        private var editedField: NSTextField? {
            (window.firstResponder as? NSTextView)?.delegate as? NSTextField
        }

        /// The question in the sheet that edits a card, once the sheet shows it.
        private var sheetQuestion: String? {
            window.attachedSheet?.contentView.flatMap { contentView in
                descendants(of: contentView)
                    .compactMap { $0 as? NSTextField }
                    .filter(\.isEditable)
                    .max { $0.convert($0.bounds, to: nil).maxY < $1.convert($1.bounds, to: nil).maxY }?
                    .stringValue
            }
        }

        private func descendants(of view: NSView) -> [NSView] {
            view.subviews.flatMap { [$0] + descendants(of: $0) }
        }

        private func showList() async throws -> NSTableView {
            try await waitUntil("the table shows the cards") { tableView?.numberOfRows == 3 }
            return try #require(tableView)
        }

        /// Clicks at `point` of `view`; with a `clickCount` of 2 as the second click of a
        /// double-click. The mouse-up is queued first: the view tracks the mouse until it
        /// comes.
        private func click(at point: NSPoint, in view: NSView, clickCount: Int = 1) throws {
            let location = view.convert(point, to: nil)
            func event(_ type: NSEvent.EventType) throws -> NSEvent {
                try #require(
                    NSEvent.mouseEvent(
                        with: type, location: location, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                        windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: clickCount, pressure: 1
                    )
                )
            }
            let mouseDown = try event(.leftMouseDown)
            NSApp.postEvent(try event(.leftMouseUp), atStart: false)
            window.sendEvent(mouseDown)
        }

        /// Clicks at `point` of `view` the way the mouse does: through the application, which
        /// shows the event to the monitors before the window gets it. The mouse-up follows at
        /// once: the view tracks the mouse until it comes.
        private func clickThroughApplication(at point: NSPoint, in view: NSView) throws {
            let location = view.convert(point, to: nil)
            for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
                NSApp.postEvent(try mouseEvent(type, at: location), atStart: false)
            }
        }

        private func mouseEvent(_ type: NSEvent.EventType, at location: NSPoint) throws -> NSEvent {
            try #require(
                NSEvent.mouseEvent(
                    with: type, location: location, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                    windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1
                )
            )
        }

        /// The view that moves the focus into the table on a click.
        private var clickFocus: ClickFocusView? {
            window.contentView.flatMap { descendants(of: $0).lazy.compactMap { $0 as? ClickFocusView }.first }
        }

        /// Sorts by question like a click on the header of the column: the table tells its
        /// delegate, and `Table` sets its sort order.
        private func sortByQuestion(_ table: NSTableView) throws {
            let prototype = try #require(table.tableColumns.first?.sortDescriptorPrototype)
            table.sortDescriptors = [prototype]
        }

        private func focusOtherField(_ table: NSTableView) async throws -> NSTextField {
            let field = try #require(otherField)
            #expect(window.makeFirstResponder(field))
            try await waitUntil("the text field above the table has the focus") { editedField === field }
            try await updateList(table)
            return field
        }

        /// Adds a card and waits until `table` shows it. The list has then been updated
        /// since the focus last moved and knows where it is. A fixed pause isn't enough:
        /// tests running alongside may keep the main actor busy for longer.
        private func updateList(_ table: NSTableView) async throws {
            let rows = table.numberOfRows
            let text = try #require(CardText(question: "snirk \(rows)", answer: "snork"))
            step(undoManager) { document.add(text) }
            try await waitUntil("the table shows the added card") { table.numberOfRows == rows + 1 }
        }

        /// Lets the views settle, so a focus handed over on a later turn would show.
        private func settle() async throws {
            try await Task.sleep(for: .milliseconds(200))
        }

        /// A new sort order builds a new table (#168), and it takes the focus of the old one (#170).
        @Test func focusedTableHandsFocusToNewTableWhenSorted() async throws {
            defer { window.close() }
            let table = try await showList()
            #expect(window.makeFirstResponder(table))
            // SwiftUI copies the first responder into `tableIsFocused` on its next update, and the
            // sort reads it to know that the table has the focus. A host that isn't active
            // updates 20 to 60 ms late, and a sort 15 ms after the focus beats it: the sort then
            // hands over no focus. Update now.
            window.contentView?.layoutSubtreeIfNeeded()
            try await updateList(table)

            try sortByQuestion(table)
            try await waitUntil("a new table replaces the old one") { tableView.map { $0 !== table } ?? false }
            try await waitUntil("the new table has the focus") { tableView.map { window.firstResponder === $0 } ?? false }
        }

        @Test func focusedFieldKeepsFocusWhenSorted() async throws {
            defer { window.close() }
            let table = try await showList()
            let field = try await focusOtherField(table)

            try sortByQuestion(table)
            try await waitUntil("a new table replaces the old one") { tableView.map { $0 !== table } ?? false }
            try await settle()
            #expect(editedField === field)
        }

        /// Before #171 the table lost the click that moved the focus into it: the first click,
        /// from another text field, selects the row and makes the table first responder, so
        /// Delete, ⌘E and the arrow keys act on the selection.
        ///
        /// A click of the mouse selects the row without asking for the focus on macOS 27: the
        /// hosting view of the cell takes it, and `NSTableView.mouseDown`, which would make the
        /// table first responder, doesn't run (measured with a real click on 22.10.2026), see
        /// `TableClickFocus`. This click goes through the application, as the mouse's does.
        /// It needs a host app that is active: in one that isn't, the window takes the first
        /// click only to become key, and the row isn't selected.
        @Test func firstClickIntoTableSelectsRow() async throws {
            defer { window.close() }
            let table = try await showList()
            _ = try await focusOtherField(table)

            let rect = table.rect(ofRow: 1)
            try clickThroughApplication(at: NSPoint(x: rect.midX, y: rect.midY), in: table)
            try await waitUntil("the row is selected") { table.selectedRowIndexes == [1] }
            try await waitUntil("the table is first responder") { window.firstResponder === table }
        }

        /// What `TableClickFocus` does with a click, whether or not the window takes the click: a
        /// click on a row moves the focus into the table, a click anywhere else leaves it where
        /// it is.
        @Test func aClickInTheTableMovesTheFocusIntoItAndOneOutsideDoesNot() async throws {
            defer { window.close() }
            let table = try await showList()
            let field = try await focusOtherField(table)
            let focus = try #require(clickFocus)

            let outside = field.convert(NSPoint(x: field.bounds.midX, y: field.bounds.midY), to: nil)
            focus.mouseDown(in: try mouseEvent(.leftMouseDown, at: outside))
            try await settle()
            #expect(editedField === field)

            let rect = table.rect(ofRow: 1)
            let inRow = table.convert(NSPoint(x: rect.midX, y: rect.midY), to: nil)
            focus.mouseDown(in: try mouseEvent(.leftMouseDown, at: inRow))
            try await waitUntil("the table is first responder") { window.firstResponder === table }
        }

        /// A double-click on a row opens the sheet that edits its card, but only while the
        /// deck can be changed (#241).
        @Test(arguments: [true, false])
        func doubleClickOnRowEditsItsCard(isEditable: Bool) async throws {
            window.contentView = NSHostingView(rootView: CardListView(document: document, isEditable: isEditable))
            defer {
                if let sheet = window.attachedSheet {
                    window.endSheet(sheet)
                }
                window.close()
            }
            let table = try await showList()

            let rect = table.rect(ofRow: 1)
            let center = NSPoint(x: rect.midX, y: rect.midY)
            try click(at: center, in: table)
            try click(at: center, in: table, clickCount: 2)
            try await waitUntil("the row is selected") { table.selectedRowIndexes == [1] }
            if isEditable {
                try await waitUntil("the sheet edits the card of the row") { sheetQuestion == "blim" }
            } else {
                try await settle()
                #expect(window.attachedSheet == nil)
            }
        }
    }
}
