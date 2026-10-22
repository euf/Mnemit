import Foundation

extension AnkiImport {
    /// New cards for `notes` in the order given, with the learning state of each one rebuilt
    /// by studying its reviews from scratch: the path that merges and the optimizer's
    /// replay use (`Scheduler.replaying(_:of:)`), so the deck's own FSRS parameters,
    /// steps and fuzz apply, and a card comes out as if it had been studied here. The log of
    /// the card holds the reviews. A note without reviews gives a new card, a suspended one a
    /// suspended card. A card has the `note` and the `kind` of its `Note`.
    ///
    /// Anki's own memory state is not read, so stability and difficulty follow the deck's
    /// parameters rather than Anki's.
    ///
    /// - Parameters:
    ///   - notes: With the reviews of each oldest first, as `read(_:)` gives them.
    ///   - learningOptions: Those of the deck the cards go to.
    ///   - calendar: The one the deck is studied with, which dates the due days.
    ///   - created: The creation date of the cards, which is also when suspended ones were suspended.
    /// - Returns: A card per note that has a text, an image or a sound on each side; every card has an
    ///   ID of its own, and a side with media only has an empty text.
    public static func cards(from notes: [Note], learningOptions: LearningOptions, calendar: StudyCalendar, created: Date) -> [Card] {
        let scheduler = Scheduler(learningOptions: learningOptions, calendar: calendar)
        return notes.compactMap { note in
            let question = CardText.trimmed(note.front)
            let answer = CardText.trimmed(note.back)
            guard !question.isEmpty || note.media.hasQuestionMedia, !answer.isEmpty || note.media.hasAnswerMedia else { return nil }
            // A side may have no text but an image or a sound, which `CardText` doesn't allow.
            let start = Card(
                question: question, answer: answer, note: Card.normalized(note.note), kind: note.kind, media: note.media.checked,
                created: created, learningState: nil)
            var card = scheduler.replaying(note.reviews, of: start)
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
    ///
    /// `learningOptions` are the options the cards were made with, for a deck that is new
    /// (`AnkiImport.learningOptions(applyingTo:)`): the deck takes them in the same change, so
    /// one undo takes both back. Pass them only for a deck without cards: the cards of the deck
    /// are not replayed again.
    ///
    /// `media` are the files the cards name (`AnkiImport.media`): the deck takes those the cards
    /// it adds name, in the same change, and the one undo takes out those that are new to it.
    public static func importing(_ cards: [Card], into deck: Deck, learningOptions: LearningOptions? = nil, media: DeckMedia = DeckMedia()) -> DeckChange? {
        var ids = Set(deck.cards.map(\.id))
        let added = cards.filter { ids.insert($0.id).inserted }
        var options = learningOptions
        options?.sanitize()
        guard !added.isEmpty else { return nil }
        var change = DeckChange(upserts: added, learningOptions: options == deck.learningOptions ? nil : options)
        change.addedMedia = media.keeping(added.reduce(into: Set<String>()) { $0.formUnion($1.media.names) })
        return change
    }
}
