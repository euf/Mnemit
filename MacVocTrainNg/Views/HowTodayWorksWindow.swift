import AppKit
import SwiftUI
import VocabCore

/// The window "How Today Works" of the Study menu: the figures under the ring and the rounds, for the decks
/// that are open (`OpenDecks`, as the ring on the Mac counts them). One window; asking again brings it to the
/// front and works the figures out anew.
// ponytail: the decks are named by their place, Deck 1, Deck 2, as `OpenDecks` holds documents without names;
// give `OpenDecks.add` the file name if two decks open at once are hard to tell apart here.
@MainActor
enum HowTodayWorksWindow {
    private static var window: NSWindow?

    static func show() {
        let documents = OpenDecks.shared.documents
        let sources = documents.map { HowTodayWorks.Source(name: nil, deck: $0.deck) }
        let calendar = documents.first?.calendar ?? StudyCalendar()
        let now = documents.first?.clock.now ?? Date()
        let content = NSHostingController(rootView: Loader(sources: sources, now: now, calendar: calendar))
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

    /// Replays the logs off the main actor, then shows the figures.
    private struct Loader: View {
        var sources: [HowTodayWorks.Source]
        var now: Date
        var calendar: StudyCalendar
        @State private var content: HowTodayWorks?

        var body: some View {
            HowTodayWorksView(content: content)
                .task {
                    let (sources, now, calendar) = (sources, now, calendar)
                    content = await Task.detached(priority: .utility) { HowTodayWorks.make(sources, at: now, calendar: calendar) }.value
                }
        }
    }
}
