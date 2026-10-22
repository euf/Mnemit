import Foundation
import Observation
import VocabCore

/// What today's session takes from each known deck, for the start screen's deck list.
///
/// Reads the packages without opening them as documents (`DeckFileReader`): the start
/// screen shows while no deck is open, and a document per deck would keep every file
/// open. The review log is read too, as the daily limit on new cards depends on it. A deck
/// that can't be read, e.g. one iCloud Drive has not downloaded yet, has no entry. The new
/// cards are those of the deck's allowance for the day (`NewCardAllowances`).
@MainActor @Observable
final class KnownDeckCounts {
    private(set) var counts: [URL: StudyCounts] = [:]

    /// Reads the decks one after the other, off the main actor. The allowances are those the daily
    /// ring worked out; the call comes after its evaluation.
    func refresh(_ decks: [KnownDeck], allowances: NewCardAllowances = NewCardAllowances.today) async {
        for deck in decks {
            let url = deck.url
            let allowance = allowances[url]
            counts[url] = await Task.detached(priority: .utility) { Self.counts(at: url, allowance: allowance) }.value
        }
    }

    nonisolated static func counts(at url: URL, allowance: Int? = nil) -> StudyCounts? {
        counts(at: url, on: [Date()], allowance: allowance)?.first
    }

    /// What a session would take at each of `dates`, from one read of the deck, for the
    /// reminders: cards that come due until then count. `nil` if the deck can't be read.
    ///
    /// The deck comes with its review log, as the one the deck screen counts: the daily
    /// limit on new cards subtracts the cards whose first review fell on the day, and only
    /// the log knows them. Without it every limit looks untouched.
    ///
    /// The new cards are limited by `allowance`, today's, at every date: a later day admits about as
    /// many as this one does, which no one can know before it has begun.
    nonisolated static func counts(at url: URL, on dates: [Date], allowance: Int? = nil) -> [StudyCounts]? {
        guard let deck = DeckFileReader.deck(at: url) else { return nil }
        let calendar = StudyCalendar()
        return dates.map { StudySession.counts(for: deck, at: $0, calendar: calendar, newCardAllowance: allowance) }
    }
}
