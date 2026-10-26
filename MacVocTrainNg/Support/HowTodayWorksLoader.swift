import SwiftUI
import VocabCore

/// The figures of "How It Works" over `AllDecks`: the open decks as their documents have them, the others read from
/// their files and every log replayed off the main actor, with a spinner until they are there. The Progress page's sheet shows it.
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
