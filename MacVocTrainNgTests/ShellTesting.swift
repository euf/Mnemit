import AppKit
import SwiftUI
import Testing

@testable import MacVocTrain
@testable import VocabCore

/// A `Shell` over what the tests of the one window need and nothing else: a folder of decks in a temporary directory,
/// defaults of their own and a registry of open decks that is not the app's. Tests that open decks nest under
/// `DeckFileTests`, which runs one at a time (see there).
@MainActor
final class ShellFixture {
    let directory: URL
    let folderURL: URL
    let defaults: UserDefaults
    let shell: Shell
    private let suite = "shell-test-\(UUID().uuidString)"

    /// A folder with the decks `decks`, each of that many new cards.
    init(decks: [(name: String, cards: Int)] = []) throws {
        directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        folderURL = directory.appending(path: "Mnemit", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        defaults = try #require(UserDefaults(suiteName: suite))
        let folder = DeckFolder(defaults: defaults)
        shell = Shell(folder: folder, decks: OpenDecks(), defaults: defaults)
        for (name, cards) in decks {
            try Self.write(cards: cards, to: url(name))
        }
        folder.use(folderURL)
    }

    /// Where the deck `name` of the folder is, or would be.
    func url(_ name: String) -> URL {
        folderURL.appending(path: "\(name).mnemit", directoryHint: .isDirectory)
    }

    /// A deck of `cards` new cards, written to `url`.
    @discardableResult
    static func write(cards: Int, to url: URL) throws -> URL {
        let deck = try Deck(cards: (0..<cards).map { Card(text: CardText(question: "word \($0)", answer: "x")!, created: .now.addingTimeInterval(-60)) })
        try DeckFile.fileWrapper(for: deck).write(to: url, options: .atomic, originalContentsURL: nil)
        return url
    }

    /// `waitUntil` with the generous deadline of the tests of open decks: they wait for NSDocument and the merge after
    /// it, which need the main actor, and other tests keep it busy for seconds at a time.
    func waitFor(_ comment: Comment, sourceLocation: SourceLocation = #_sourceLocation, _ condition: () -> Bool) async throws {
        try await waitUntil(comment, timeout: .seconds(120), sourceLocation: sourceLocation, condition)
    }

    /// Opens the deck `name` through the shell and waits until it can be changed.
    @discardableResult
    func open(_ name: String) async throws -> (deck: OpenDeck, document: VocabularyDocument) {
        let deck = shell.deck(for: url(name))
        try await waitFor("the deck \(name) is open and can be changed") { deck.document != nil && deck.isEditable }
        return (deck, try #require(deck.document))
    }

    /// Reads the folder and waits until the shell has read every deck, as the sidebar's badges need.
    func waitUntilRead(decks count: Int) async throws {
        shell.refresh()
        try await waitFor("the shell has read \(count) decks") { shell.counts.counts.count + shell.counts.paused.count == count }
    }

    /// A review of the first card due in one undo group of its own, which NSDocument counts as one edit, as an event of
    /// the app would: the tests have no event loop that closes the group. Easy takes a new card out of the day.
    /// `closesGroup: false` leaves the group open for a tenth of a second, as the app's run loop leaves the group of an
    /// event open until its turn is over: a quit right behind the grade meets the group open.
    func review(_ deck: OpenDeck, _ document: VocabularyDocument, grade: Grade = .good, closesGroup: Bool = true) throws {
        deck.undoManager.groupsByEvent = false
        var mode = SessionMode.study(StudySession(deck: document.deck, at: document.clock.now, calendar: document.calendar))
        guard case let .rescheduled(change) = mode.grade(grade, in: document.deck, at: document.clock.now, calendar: document.calendar) else {
            Issue.record("The study session didn't reschedule the card.")
            return
        }
        let manager = deck.undoManager
        if closesGroup {
            step(manager) { document.applyReview(change, alongside: UndoCompanion(undo: {}, redo: {})) }
        } else {
            manager.beginUndoGrouping()
            document.applyReview(change, alongside: UndoCompanion(undo: {}, redo: {}))
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(100))
                manager.endUndoGrouping()
            }
        }
    }

    /// Saves and closes the decks and removes the files.
    func finish() async {
        await shell.closeAll()
        defaults.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: directory)
    }

    /// A window with the shell's view in it, as the app's one window will have it. One that never shows draws in the
    /// window's appearance, which one ordered front, and not active, does not for the colour scheme of SwiftUI.
    func window(width: CGFloat = 1000, height: CGFloat = 640, dark: Bool = false, shown: Bool = true) -> NSWindow {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: height), styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        window.contentView = NSHostingView(rootView: ShellView(shell: shell).brandTint().environment(\.colorScheme, dark ? .dark : .light).frame(width: width, height: height))
        if shown { window.makeKeyAndOrderFront(nil) }
        return window
    }
}
