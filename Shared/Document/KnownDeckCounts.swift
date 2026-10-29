import Foundation
import Observation
import VocabCore

/// What today's session takes from each known deck, for the deck lists of Today on the iPhone and the Mac.
///
/// Reads the packages without opening them as documents (`DeckFileReader`): the start
/// screen shows while no deck is open, and a document per deck would keep every file
/// open. The review log is read too, as the daily limit on new cards depends on it. A deck
/// that can't be read, e.g. one iCloud Drive has not downloaded yet, has no entry. The new
/// cards are those of the deck's allowance for the day (`NewCardAllowances`).
///
/// A paused deck (`LearningOptions.isPaused`) asks nothing of the day: it has no counts, and is in
/// `paused` instead, which also tells the list it was read. A deck that can't be read is in `failed`, with the
/// reason: it was tried, so the day is told without it and its row says why it has no figures.
@MainActor @Observable
final class KnownDeckCounts {
    private(set) var counts: [URL: StudyCounts] = [:]
    /// The decks that were read and are paused.
    private(set) var paused: Set<URL> = []

    /// The decks that were tried and can't be read, with why: too new, damaged, not downloaded yet.
    private(set) var failed: [URL: String] = [:]

    /// Whether any deck was tried yet: until then the figures are placeholders.
    var isRead: Bool { !counts.isEmpty || !paused.isEmpty || !failed.isEmpty }

    /// Reads the decks one after the other, off the main actor. The allowances are those the daily
    /// ring worked out; the call comes after its evaluation.
    func refresh(_ urls: [URL], allowances: NewCardAllowances = NewCardAllowances.today) async {
        for url in urls {
            let allowance = allowances[url]
            let read = await Task.detached(priority: .utility) { Self.read(at: url, on: [Date()], allowance: allowance) }.value
            counts[url] = (try? read.get()).flatMap { $0.isPaused ? nil : $0.counts.first }
            if case let .success(read) = read, read.isPaused {
                paused.insert(url)
            } else {
                paused.remove(url)
            }
            if case let .failure(failure) = read {
                failed[url] = failure.reason
            } else {
                failed[url] = nil
            }
        }
    }

    /// What a session would take now; `nil` if the deck can't be read or is paused.
    nonisolated static func counts(at url: URL, allowance: Int? = nil) -> StudyCounts? {
        counts(at: url, on: [Date()], allowance: allowance)?.first
    }

    /// What a session would take at each of `dates`, from one read of the deck, for the
    /// reminders: cards that come due until then count. `nil` if the deck can't be read, and
    /// for a paused one, which asks nothing of the day: the reminders and the widget leave it out.
    ///
    /// The deck comes with its review log, as the one the deck screen counts: the daily
    /// limit on new cards subtracts the cards whose first review fell on the day, and only
    /// the log knows them. Without it every limit looks untouched.
    ///
    /// The new cards are limited by `allowance`, today's, at every date: a later day admits about as
    /// many as this one does, which no one can know before it has begun.
    nonisolated static func counts(at url: URL, on dates: [Date], allowance: Int? = nil) -> [StudyCounts]? {
        guard let read = try? read(at: url, on: dates, allowance: allowance).get(), !read.isPaused else { return nil }
        return read.counts
    }

    /// The counts at `dates` and whether the deck is paused, from one read; why not if it can't be read.
    nonisolated private static func read(at url: URL, on dates: [Date], allowance: Int?) -> Result<(counts: [StudyCounts], isPaused: Bool), DeckReadFailure> {
        DeckFileReader.read(at: url).map { deck in
            let calendar = StudyCalendar()
            return (dates.map { StudySession.counts(for: deck, at: $0, calendar: calendar, newCardAllowance: allowance) }, deck.learningOptions.isPaused)
        }
    }
}
