import AppKit
import SwiftUI
import Testing

@testable import MacVocTrain
@testable import VocabCore

extension WindowTests {
    /// The card list's scope bar and the Kind column, in a real window.
    @MainActor
    struct CardBrowserTests {
        let document: VocabularyDocument
        let window: NSWindow

        init() throws {
            let now = Date()
            func state(_ phase: LearningPhase, due: TimeInterval, lapses: Int = 0) -> LearningState {
                LearningState(phase: phase, stability: 10, difficulty: 5, lastReview: now.addingTimeInterval(-86400), due: now.addingTimeInterval(due), reviews: lapses + 3, lapses: lapses)
            }
            var suspended = Card(question: "suspended", answer: "x", note: "s", kind: .production)
            suspended.isSuspended = true
            document = try VocabularyDocument(
                deck: Deck(cards: [
                    Card(question: "new", answer: "x", note: "n", kind: .recognition),
                    Card(question: "due", answer: "x", learningState: state(.review, due: -3600)),
                    Card(question: "later", answer: "x", note: "l", kind: .production, learningState: state(.review, due: 86400)),
                    Card(question: "learning", answer: "x", learningState: state(.learning, due: 600)),
                    suspended,
                    Card(question: "leech", answer: "x", learningState: state(.review, due: -60, lapses: 8)),
                ])
            )
            window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1000, height: 600), styleMask: [.titled], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: CardListView(document: document, isEditable: true))
            window.makeKeyAndOrderFront(nil)
        }

        private func descendants(of view: NSView) -> [NSView] {
            view.subviews.flatMap { [$0] + descendants(of: $0) }
        }

        private var tableView: NSTableView? {
            window.contentView.flatMap { descendants(of: $0).lazy.compactMap { $0 as? NSTableView }.first }
        }

        private var scopeBar: NSSegmentedControl? {
            window.contentView.flatMap { descendants(of: $0).lazy.compactMap { $0 as? NSSegmentedControl }.first }
        }

        private func choose(_ segment: Int, in bar: NSSegmentedControl) throws {
            bar.selectedSegment = segment
            let action = try #require(bar.action)
            #expect(NSApp.sendAction(action, to: bar.target, from: bar))
        }

        /// Filter names are the spec's, in its order; every segment carries the count of its
        /// filter in the whole deck.
        @Test func theScopeBarShowsTheFiltersWithTheirCounts() async throws {
            defer { window.close() }
            try await waitUntil("the scope bar is shown") { scopeBar != nil }
            let bar = try #require(scopeBar)
            #expect(bar.segmentCount == 6)
            let labels = (0..<bar.segmentCount).map { bar.label(forSegment: $0) }
            // The names come in the language the test runs in.
            let counts = [6, 2, 1, 1, 1, 1]
            #expect(labels == zip(CardFilter.allCases, counts).map { "\($0.title) \($1)" })
            #expect(CardFilter.allCases.map(\.rawValue) == ["all", "due", "new", "learning", "suspended", "leeches"])
            #expect(bar.selectedSegment == 0)
        }

        @Test(arguments: [(1, 2), (2, 1), (3, 1), (4, 1), (5, 1), (0, 6)])
        func aFilterShowsItsCards(segment: Int, rows: Int) async throws {
            defer { window.close() }
            try await waitUntil("the table shows the cards") { tableView?.numberOfRows == 6 }
            let bar = try #require(scopeBar)
            try choose(segment, in: bar)
            try await waitUntil("the table shows \(rows) rows") { tableView?.numberOfRows == rows }
        }

        /// Where the segments don't fit, as in a window at its minimum width with the inspector
        /// open, the same filters are a menu; the table stays. SwiftUI draws that menu itself,
        /// so the test sees only that the segmented control is gone.
        @Test func aNarrowListSwapsTheSegmentsForAMenu() async throws {
            defer { window.close() }
            try await waitUntil("the scope bar is shown") { scopeBar != nil }
            window.contentView = NSHostingView(rootView: CardListView(document: document, isEditable: true).frame(width: 300, height: 500))
            try await waitUntil("the table shows the cards") { tableView?.numberOfRows == 6 }
            #expect(scopeBar == nil)
        }

        /// The inspector of a card with a kind, a word key, a sibling and a history builds and
        /// lays out; its buttons are no AppKit views since macOS 26, so what it shows is for
        /// a look at the window.
        @Test func theInspectorBuildsForACardWithSiblingAndHistory() async throws {
            defer { window.close() }
            let state = LearningState(phase: .review, stability: 10, difficulty: 5, lastReview: Date(), due: Date().addingTimeInterval(86400), reviews: 3, lapses: 1)
            let log = Grade.allCases.map { ReviewLogEntry(date: Date(), grade: $0) }
            let word = Card(question: "αγαπώ", answer: "lieben", note: "αγαπώ", kind: .recognition, learningState: state, log: log)
            let sibling = Card(question: "lieben", answer: "αγαπώ", note: "αγαπώ", kind: .production)
            let deck = try VocabularyDocument(deck: Deck(cards: [word, sibling]))
            var selected: [Card.ID] = []
            let inspector = NSHostingView(
                rootView: CardInspector(document: deck, selection: [word.id], isEditable: true, onEdit: { _ in }, onDelete: { _ in }, onSelect: { selected.append($0) })
            )
            let inspectorWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 700), styleMask: [.titled], backing: .buffered, defer: false)
            inspectorWindow.isReleasedWhenClosed = false
            inspectorWindow.contentView = inspector
            inspectorWindow.makeKeyAndOrderFront(nil)
            defer { inspectorWindow.close() }
            try await Task.sleep(for: .milliseconds(300))
            #expect(inspector.fittingSize.height > 100)
            #expect(selected.isEmpty)
            #expect(deck.deck.siblings(of: word).map(\.id) == [sibling.id])
        }

        @Test func theKindColumnShowsTheDirectionAndSorts() async throws {
            defer { window.close() }
            try await waitUntil("the table shows the cards") { tableView?.numberOfRows == 6 }
            let table = try #require(tableView)
            let column = try #require(table.tableColumns.first { $0.title == String(localized: "Kind") })
            #expect(column.sortDescriptorPrototype != nil)
            // After Question, Answer and Hint.
            #expect(table.tableColumns.firstIndex(of: column) == 3)
        }
    }
}
