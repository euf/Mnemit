import Foundation

extension AnkiImport {
    /// New cards for `notes` in the order given, with the learning state of each one rebuilt
    /// by studying its reviews from scratch: the path that merges and the optimizer's
    /// replay use (`Scheduler.replaying(_:of:)`), so the deck's own FSRS parameters,
    /// steps and fuzz apply, and a card comes out as if it had been studied here. The log of
    /// the card holds the reviews. A note without reviews gives a new card, a suspended one a
    /// suspended card.
    ///
    /// Anki's own memory state is not read, so stability and difficulty follow the deck's
    /// parameters rather than Anki's.
    ///
    /// - Parameters:
    ///   - notes: With the reviews of each oldest first, as `read(_:)` gives them.
    ///   - learningOptions: Those of the deck the cards go to.
    ///   - calendar: The one the deck is studied with, which dates the due days.
    ///   - created: The creation date of the cards, which is also when suspended ones were suspended.
    /// - Returns: A card per note whose front and back aren't empty; every card has an ID of its own.
    public static func cards(from notes: [Note], learningOptions: LearningOptions, calendar: StudyCalendar, created: Date) -> [Card] {
        let scheduler = Scheduler(learningOptions: learningOptions, calendar: calendar)
        return notes.compactMap { note in
            guard let text = CardText(question: note.front, answer: note.back) else { return nil }
            var card = scheduler.replaying(note.reviews, of: Card(text: text, created: created))
            if note.isSuspended {
                card.suspend(at: created)
            }
            return card
        }
    }

    /// `cards(from:learningOptions:calendar:created:)` of the notes of the package.
    public func cards(learningOptions: LearningOptions, calendar: StudyCalendar, created: Date) -> [Card] {
        Self.cards(from: notes, learningOptions: learningOptions, calendar: calendar, created: created)
    }
}

extension DeckChange {
    /// Appends `cards` to `deck` with the learning state and the review log they come
    /// with, as `AnkiImport.cards(from:learningOptions:calendar:created:)` makes them, for
    /// an import that brings history along (`adding(_:to:)` takes new cards only). Cards
    /// whose ID `deck` holds already are left out, so it never replaces a card; `nil` if
    /// that leaves none.
    public static func importing(_ cards: [Card], into deck: Deck) -> DeckChange? {
        var ids = Set(deck.cards.map(\.id))
        let added = cards.filter { ids.insert($0.id).inserted }
        return added.isEmpty ? nil : DeckChange(upserts: added)
    }
}
