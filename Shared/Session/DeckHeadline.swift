import Foundation
import VocabCore

/// The one line at the top of the screen: "14 cards today", "Done · next review tomorrow" with a check, "Paused".
/// `nil` for a deck with no cards, whose screen has nothing to say yet.
struct DeckHeadline: Equatable {
    var text: String
    var isDone: Bool

    /// - Parameters:
    ///   - counts: The deck's plan for today; `nil` before the list has read it.
    ///   - pace: The day's pace, which prices the plan as "≈ 4 min"; `nil` leaves the time out.
    ///   - hasCards: Whether the deck has any card.
    init?(counts: StudyCounts?, pace: Pace? = nil, isPaused: Bool, hasCards: Bool, now: Date) {
        if isPaused {
            self.init(text: String(localized: "Paused"), isDone: false)
        } else if let counts, counts.total > 0 {
            self.init(text: Self.counts(counts, pace: pace), isDone: false)
        } else if let counts, hasCards {
            let next = counts.nextDue.map { String(localized: "Done · next review \(Format.due($0, now: now))") }
            self.init(text: next ?? String(localized: "Done"), isDone: true)
        } else {
            return nil
        }
    }

    init(text: String, isDone: Bool) {
        self.text = text
        self.isDone = isDone
    }

    /// "≈ 4 min · 14 due · 6 new · 2 learning": Anki's counts (`StudyCounts.due`, `.new`, `.learning`) after the time of the
    /// plan; a count of 0 is left out.
    static func counts(_ counts: StudyCounts, pace: Pace?) -> String {
        let time = DeckMinutes.minutes(counts, pace: pace).map(Format.timeLeft(minutes:))
        let parts = [
            time, counts.due > 0 ? String(localized: "\(counts.due) due") : nil, counts.new > 0 ? String(localized: "\(counts.new) new") : nil,
            counts.learning > 0 ? String(localized: "\(counts.learning) learning") : nil,
        ]
        return parts.compactMap { $0 }.joined(separator: " · ")
    }
}

/// What a deck's plan for the rest of today takes at the day's pace: its share of the minutes left, for the deck's row and
/// the header of its screen.
enum DeckMinutes {
    /// Whole minutes up, 0 for under one; `nil` for no cards and without a pace.
    static func minutes(_ counts: StudyCounts, pace: Pace?) -> Int? {
        guard let pace else { return nil }
        return DailyGoal.minutesLeft(newCards: counts.newAtDayStart, otherCards: counts.total - counts.newAtDayStart, pace: pace)
    }
}
