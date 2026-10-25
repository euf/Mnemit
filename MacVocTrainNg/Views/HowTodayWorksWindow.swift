import AppKit
import SwiftUI
import VocabCore

/// The window "How Today Works" of the Study menu and of Progress: the figures under the ring and the rounds, for
/// every deck of the Mnemit folder (`AllDecks`, as the ring on the Mac counts them), each named by its file. One
/// window; asking again brings it to the front and works the figures out anew.
@MainActor
enum HowTodayWorksWindow {
    private static var window: NSWindow?

    static func show() {
        let decks = AllDecks.current()
        let sources = decks.documents.map { HowTodayWorks.Source(name: $0.packageURL?.deletingPathExtension().lastPathComponent, deck: $0.deck) }
        let calendar = decks.documents.first?.calendar ?? StudyCalendar()
        let now = decks.documents.first?.clock.now ?? Date()
        let content = NSHostingController(rootView: Loader(sources: sources, files: decks.files, now: now, calendar: calendar).brandTint())
        if let window {
            window.contentViewController = content
            window.makeKeyAndOrderFront(nil)
            return
        }
        let window = NSWindow(contentViewController: content)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.title = String(localized: "How Today Works")
        window.setContentSize(NSSize(width: 520, height: 760))
        window.isReleasedWhenClosed = false
        window.center()
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { _ in
            MainActor.assumeIsolated { Self.window = nil }
        }
        self.window = window
        window.makeKeyAndOrderFront(nil)
    }

    /// Reads the decks that aren't open and replays the logs off the main actor, then shows the figures.
    private struct Loader: View {
        var sources: [HowTodayWorks.Source]
        var files: [URL]
        var now: Date
        var calendar: StudyCalendar
        @State private var content: HowTodayWorks?

        var body: some View {
            HowTodayWorksView(content: content)
                .task {
                    let (sources, files, now, calendar) = (sources, files, now, calendar)
                    content = await Task.detached(priority: .utility) {
                        let read = files.compactMap { url in
                            DeckFileReader.deck(at: url).map { HowTodayWorks.Source(name: url.deletingPathExtension().lastPathComponent, deck: $0) }
                        }
                        return HowTodayWorks.make(sources + read, at: now, calendar: calendar, swipes: nil)
                    }.value
                }
        }
    }
}
