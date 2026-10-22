import Foundation
import VocabCore

/// The known decks as Today lists them: the decks that take part in the day, then the paused ones
/// (`LearningOptions.isPaused`) in a section of their own. A paused deck is left out of what the Study
/// button runs, and so of the "Next: …" that follows a stream, but stays open to the learner.
struct TodayDecks: Equatable {
    /// The decks of the day, in the order of the list.
    var active: [KnownDeck]
    /// The paused decks, in the order of the list.
    var paused: [KnownDeck]

    /// - Parameter paused: The decks read as paused (`KnownDeckCounts.paused`).
    init(_ decks: [KnownDeck], paused pausedURLs: Set<URL> = []) {
        active = decks.filter { !pausedURLs.contains($0.url) }
        paused = decks.filter { pausedURLs.contains($0.url) }
    }

    /// The decks Study runs one after the other: those of the day with cards left, the one `last` studied
    /// first and the others in the order of the list. With nothing left, the deck studied last alone, or
    /// the first of the day: its stream rests at once and offers to go on. Before the decks are read
    /// (`isRead`) every deck of the day counts as due. Empty without a deck of the day.
    func studyQueue(counts: [URL: StudyCounts], isRead: Bool, last: URL?) -> [URL] {
        let urls = active.map(\.url)
        var due = urls.filter { counts[$0].map { $0.total > 0 } ?? !isRead }
        let last = last.flatMap { last in urls.first { $0 == last } }
        if let last, let index = due.firstIndex(of: last) {
            due.insert(due.remove(at: index), at: 0)
        }
        if due.isEmpty, let rest = last ?? urls.first {
            return [rest]
        }
        return due
    }
}
