import Foundation
import Observation
import VocabCore

/// What today's session takes from each known deck, for the start screen's deck list.
///
/// Reads the packages without opening them as documents (`DeckFileReader`): the start
/// screen shows while no deck is open, and a document per deck would keep every file
/// open. The review log is read too, as the daily limit on new cards depends on it. A deck
/// that can't be read, e.g. one iCloud Drive has not downloaded yet, has no entry.
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
    ///
    /// The deck comes with its review log, as the one the deck screen counts: the daily
    /// limit on new cards subtracts the cards whose first review fell on the day, and only
    /// the log knows them. Without it every limit looks untouched.
    nonisolated static func counts(at url: URL, on dates: [Date]) -> [StudyCounts]? {
        guard let deck = DeckFileReader.deck(at: url) else { return nil }
        let calendar = StudyCalendar()
        return dates.map { StudySession.counts(for: deck, at: $0, calendar: calendar) }
    }
}
