import Combine
import Foundation
import Observation
import VocabCore

/// What a study session started now would take, new, learning and review cards, for
/// the deck screen, the toolbar, the menu, the session summary and the status bar of
/// the card list. A card never studied counts only as far as the session would
/// introduce it, see `StudySession.counts(for:at:calendar:newCardAllowance:)`.
///
/// Counts again after every change to the deck and at the start of every minute,
/// because cards become due as time passes. The minute is the one of
/// `TimelineView(.everyMinute)`, so the number changes together with the due dates
/// the views show. Observers hear of it only when the counts change, so a window
/// that shows them isn't redrawn every minute.
@MainActor @Observable
final class DueCardCounter {
    private(set) var counts: StudyCounts
    /// The size of the next session.
    var count: Int { counts.total }
    /// The document owns the counter.
    @ObservationIgnored private unowned let document: VocabularyDocument
    @ObservationIgnored private var subscriptions: Set<AnyCancellable> = []

    init(document: VocabularyDocument) {
        self.document = document
        counts = Self.counts(of: document)
        document.deckDidChange
            .sink { [weak self] in self?.refresh() }
            .store(in: &subscriptions)
        scheduleRefresh()
    }

    /// Counts the cards of the next session at the time of the document's clock.
    func refresh() {
        let counts = Self.counts(of: document)
        if counts != self.counts {
            self.counts = counts
        }
    }

    private static func counts(of document: VocabularyDocument) -> StudyCounts {
        StudySession.counts(for: document.deck, at: document.clock.now, calendar: document.calendar, newCardAllowance: document.newCardAllowance)
    }

    /// The start of the minute after `date`. Every time zone is a whole number of
    /// minutes off UTC, so this is the full minute on the clock as well.
    nonisolated static func nextRefresh(after date: Date) -> Date {
        let minutes = (date.timeIntervalSinceReferenceDate / 60).rounded(.down) + 1
        return Date(timeIntervalSinceReferenceDate: minutes * 60)
    }

    /// Refreshes at the next full minute and schedules the one after. A timer that
    /// repeats every 60 seconds would tick at the second the document was opened.
    ///
    /// The timer runs in real time, not on the document's clock, which a test may
    /// hold still. Once the counter is gone, the last timer fires without effect.
    private func scheduleRefresh() {
        let timer = Timer(fire: Self.nextRefresh(after: Date()), interval: 0, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refresh()
                self?.scheduleRefresh()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
    }
}
