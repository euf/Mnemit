import AppKit
import SwiftUI
import VocabCore

/// Today, the window at launch while no document is open, instead of the bare Open panel: the day over the decks
/// of the Mnemit folder and the decks themselves, or, before the folder is chosen, the ways in (`WelcomeView`). It
/// stays open beside the deck windows, as the iPhone's Today stays under a deck. Window ▸ Today (⌘0) brings it
/// back, and so does a click on the Dock icon while no document is open.
///
/// `defaults write <bundle id> showsWelcomeWindow -bool NO` goes back to AppKit's own
/// behaviour at launch.
@MainActor
enum WelcomeWindow {
    static let enabledKey = "showsWelcomeWindow"

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    }

    private static var window: NSWindow?

    static func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            return
        }
        let window = NSWindow(contentViewController: NSHostingController(rootView: WelcomeView().brandTint()))
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.title = String(localized: "Today")
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.center()
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { _ in
            MainActor.assumeIsolated { Self.window = nil }
        }
        self.window = window
        window.makeKeyAndOrderFront(nil)
    }

    static func close() {
        window?.close()
    }

    /// At launch, once documents that were open at quit, or that Finder asked for, have had
    /// time to open.
    static func showAtLaunchIfNoDocumentOpens() async {
        try? await Task.sleep(for: .milliseconds(600))
        guard NSDocumentController.shared.documents.isEmpty else { return }
        // Should AppKit have shown its Open panel anyway, the welcome window takes its place.
        for case let panel as NSOpenPanel in NSApp.windows {
            panel.cancel(nil)
        }
        show()
    }
}

/// What the welcome window, or Finder opening an Anki package, asks of the document window it
/// opens: to start "Import Cards…", from the package if there is one.
@MainActor
enum WelcomeRequest {
    struct Request: Identifiable {
        let id = UUID()
        /// The Anki package to import; `nil` to ask for a file.
        var file: URL?
    }

    private static var pending: [Request] = []

    /// Asks the next document window to start "Import Cards…", from `file` if given.
    static func requestImportCards(from file: URL? = nil) {
        let request = Request(file: file)
        pending.append(request)
        // A request that no window took doesn't wait for an unrelated one.
        Task {
            try? await Task.sleep(for: .seconds(5))
            pending.removeAll { $0.id == request.id }
        }
    }

    /// Imports `file`, a package or a table, into a new deck: the request, then the document whose
    /// window takes it. Finder opening a package and a download of the deck browser go this way.
    static func importIntoNewDeck(from file: URL, newDocument: () -> Void = { NSDocumentController.shared.newDocument(nil) }) {
        requestImportCards(from: file)
        newDocument()
    }

    /// The request of the import the welcome window made, once; windows take them in order.
    static func takeImportCards() -> Request? {
        pending.isEmpty ? nil : pending.removeFirst()
    }

    /// Posted when Today asks a deck to study; the deck's window takes it with `takeStudy(of:)`.
    static let studyRequested = Notification.Name("MnemitStudyRequested")

    /// What Today asks of a deck window: the stream to start, and the other decks to mix into it.
    struct StudyRequest {
        var entry: SessionViewModel.Entry
        var others: [URL]
    }

    private static var studies: [String: StudyRequest] = [:]

    /// Asks the window of the deck at `url` to start `entry`, opening the deck if it isn't open, over it and the
    /// decks at `others`, which open too, in windows of their own behind it.
    static func requestStudy(of url: URL, entry: SessionViewModel.Entry, with others: [URL] = []) {
        for other in others { DeckFolder.open(other) }
        studies[key(url)] = StudyRequest(entry: entry, others: others)
        NotificationCenter.default.post(name: studyRequested, object: nil)
        DeckFolder.open(url)
    }

    /// What Today asked of the deck at `url`, once.
    static func takeStudy(of url: URL) -> StudyRequest? {
        studies.removeValue(forKey: key(url))
    }

    /// Posted when Today asks a deck to be paused or resumed; the deck's window takes it with `takePause(of:)`.
    static let pauseRequested = Notification.Name("MnemitPauseRequested")

    private static var pauses: [String: Bool] = [:]

    /// Asks the window of the deck at `url` to pause or resume it, opening the deck if it isn't open: a deck is changed
    /// only through its document.
    static func requestPause(of url: URL, isPaused: Bool) {
        pauses[key(url)] = isPaused
        NotificationCenter.default.post(name: pauseRequested, object: nil)
        DeckFolder.open(url)
    }

    /// Whether Today asked the deck at `url` to be paused, once.
    static func takePause(of url: URL) -> Bool? {
        pauses.removeValue(forKey: key(url))
    }

    /// Posted when Today asks a deck to show a card; the deck's window takes it with `takeCard(of:)`.
    static let cardRequested = Notification.Name("MnemitCardRequested")

    private static var cards: [String: Card.ID] = [:]

    /// Asks the window of the deck at `url` to show the card `id` in its table, opening the deck if it isn't open:
    /// a hit of Today's search.
    static func requestCard(_ id: Card.ID, of url: URL) {
        cards[key(url)] = id
        NotificationCenter.default.post(name: cardRequested, object: nil)
        DeckFolder.open(url)
    }

    /// The card Today asked the deck at `url` to show, once.
    static func takeCard(of url: URL) -> Card.ID? {
        cards.removeValue(forKey: key(url))
    }

    /// The open documents of the decks at `urls`, as soon as each can be edited, waiting a few seconds at most.
    static func openDocuments(_ urls: [URL]) async -> [VocabularyDocument] {
        let wanted = Set(urls.map(key))
        func ready() -> [VocabularyDocument] {
            OpenDecks.shared.documents.filter { document in
                document.isReadyToEdit && document.packageURL.map { wanted.contains(key($0)) } == true
            }
        }
        for _ in 0..<30 where ready().count < wanted.count {
            try? await Task.sleep(for: .milliseconds(100))
        }
        return ready()
    }

    /// The same file however its URL is spelled.
    private static func key(_ url: URL) -> String {
        url.standardizedFileURL.resolvingSymlinksInPath().path
    }
}
