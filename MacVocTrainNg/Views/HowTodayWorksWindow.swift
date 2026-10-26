import AppKit
import SwiftUI
import VocabCore

/// The window "How It Works" of the Study menu and of Progress: the figures under the ring and the rounds, for
/// every deck of the Mnemit folder (`AllDecks`, as the ring on the Mac counts them), each named by its file. One
/// window; asking again brings it to the front and works the figures out anew.
@MainActor
enum HowTodayWorksWindow {
    private static var window: NSWindow?

    static func show() {
        let content = NSHostingController(rootView: HowTodayWorksLoader().brandTint())
        if let window {
            window.contentViewController = content
            window.makeKeyAndOrderFront(nil)
            return
        }
        let window = NSWindow(contentViewController: content)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.title = String(localized: "How It Works")
        window.setContentSize(NSSize(width: 520, height: 760))
        window.isReleasedWhenClosed = false
        window.center()
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { _ in
            MainActor.assumeIsolated { Self.window = nil }
        }
        self.window = window
        window.makeKeyAndOrderFront(nil)
    }
}

/// The figures of "How It Works" over `AllDecks`: the open decks as their documents have them, the others read from
/// their files and every log replayed off the main actor, with a spinner until they are there. The window and the Progress
/// page's sheet show it.
struct HowTodayWorksLoader: View {
    private var sources: [HowTodayWorks.Source]
    private var files: [URL]
    private var now: Date
    private var calendar: StudyCalendar
    @State private var content: HowTodayWorks?

    /// Takes the decks as they are now.
    @MainActor
    init(decks: OpenDecks = .shared, folder: DeckFolder = .shared) {
        let all = AllDecks.current(decks: decks, folder: folder)
        sources = all.documents.map { HowTodayWorks.Source(name: $0.packageURL?.deletingPathExtension().lastPathComponent, deck: $0.deck) }
        files = all.files
        calendar = all.documents.first?.calendar ?? StudyCalendar()
        now = all.documents.first?.clock.now ?? Date()
    }

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
