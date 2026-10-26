import Foundation
import VocabCore

/// The one line at the top of the screen: "14 cards today", "Done · next review tomorrow" with a check, "Paused".
/// `nil` for a deck with no cards, whose screen has nothing to say yet.
struct DeckHeadline: Equatable {
    var text: String
    var isDone: Bool

    /// - Parameters:
    ///   - counts: The deck's plan for today; `nil` before the list has read it.
    ///   - hasCards: Whether the deck has any card.
    init?(counts: StudyCounts?, isPaused: Bool, hasCards: Bool, now: Date) {
        if isPaused {
            self.init(text: String(localized: "Paused"), isDone: false)
        } else if let counts, counts.total > 0 {
            self.init(text: String(localized: "\(counts.total) cards today"), isDone: false)
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
}
