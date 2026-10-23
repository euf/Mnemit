import AppKit
import SwiftUI

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
        let window = NSWindow(contentViewController: NSHostingController(rootView: WelcomeView()))
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

    private static var studies: [String: SessionViewModel.Entry] = [:]

    /// Asks the window of the deck at `url` to start `entry`, opening the deck if it isn't open.
    static func requestStudy(of url: URL, entry: SessionViewModel.Entry) {
        studies[key(url)] = entry
        NotificationCenter.default.post(name: studyRequested, object: nil)
        DeckFolder.open(url)
    }

    /// What Today asked of the deck at `url`, once.
    static func takeStudy(of url: URL) -> SessionViewModel.Entry? {
        studies.removeValue(forKey: key(url))
    }

    /// The same file however its URL is spelled.
    private static func key(_ url: URL) -> String {
        url.standardizedFileURL.resolvingSymlinksInPath().path
    }
}
