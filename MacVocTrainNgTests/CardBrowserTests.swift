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
            #expect(CardFilter.allCases.map(\.rawValue) == ["all", "due", "new", "learning", "suspended", "difficult"])
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
