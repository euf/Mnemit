import Foundation
import Observation
import VocabCore

/// What today's session takes from each known deck, for the start screen's deck list.
///
/// Reads the `deck.json` of the packages without opening them as documents: the start
/// screen shows while no deck is open, and a document per deck would keep every file
/// open. The review log isn't needed for counting, so it stays unread. A deck that can't
/// be read, e.g. one iCloud Drive has not downloaded yet, has no entry.
@MainActor @Observable
final class KnownDeckCounts {
    private(set) var counts: [URL: StudyCounts] = [:]

    /// Reads the decks one after the other, off the main actor.
    func refresh(_ decks: [KnownDeck]) async {
        for deck in decks {
            let url = deck.url
            counts[url] = await Task.detached(priority: .utility) { Self.counts(at: url) }.value
        }
    }

    nonisolated static func counts(at url: URL) -> StudyCounts? {
        counts(at: url, on: [Date()])?.first
    }

    /// What a session would take at each of `dates`, from one read of the deck, for the
    /// reminders: cards that come due until then count. `nil` if the deck can't be read.
    nonisolated static func counts(at url: URL, on dates: [Date]) -> [StudyCounts]? {
        // A deck outside the app's sandbox can be read only while the app accesses it.
        let isAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        var counts: [StudyCounts]?
        var error: NSError?
        // Coordinated, as the open deck's UIDocument and the merger write the package.
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &error) { url in
            guard let data = try? Data(contentsOf: url.appendingPathComponent(DeckFile.deckFileName)),
                let deck = try? DeckFile.decode(data)
            else { return }
            let calendar = StudyCalendar()
            counts = dates.map { StudySession.counts(for: deck, at: $0, calendar: calendar) }
        }
        return counts
    }
}
