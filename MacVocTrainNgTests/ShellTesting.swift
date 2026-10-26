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
    func review(_ deck: OpenDeck, _ document: VocabularyDocument, grade: Grade = .good) throws {
        deck.undoManager.groupsByEvent = false
        var mode = SessionMode.study(StudySession(deck: document.deck, at: document.clock.now, calendar: document.calendar))
        guard case let .rescheduled(change) = mode.grade(grade, in: document.deck, at: document.clock.now, calendar: document.calendar) else {
            Issue.record("The study session didn't reschedule the card.")
            return
        }
        step(deck.undoManager) { document.applyReview(change, alongside: UndoCompanion(undo: {}, redo: {})) }
    }

    /// Saves and closes the decks and removes the files.
    func finish() async {
        await shell.closeAll()
        defaults.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: directory)
    }

    /// A window with the shell's view in it, as the app's one window will have it.
    func window(width: CGFloat = 1000, height: CGFloat = 640) -> NSWindow {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: height), styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: ShellView(shell: shell).brandTint().frame(width: width, height: height))
        window.makeKeyAndOrderFront(nil)
        return window
    }
}
