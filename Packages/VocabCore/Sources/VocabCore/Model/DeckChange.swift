import Foundation

/// One change to a deck: cards to replace or add, cards to remove, new learning
/// options and new progress. `Deck.apply(_:at:calendar:)` makes it and returns the
/// change that reverts it.
///
/// Only VocabCore builds changes: outside it, the factory methods below and
/// `SessionMode.grade(_:in:at:calendar:duration:)` are the only way. So the app can't set a
/// card's learning state or log on its own.
public struct DeckChange: Sendable {
    /// Cards to replace (matched by ID) or insert at the given index (appended if `nil`).
    /// Only the inverse of removals inserts at an index.
    var upserts: [(card: Card, index: Int?)]
    var removals: [Card.ID]
    /// New learning options; `nil` keeps them.
    var learningOptions: LearningOptions?
    /// New progress, before the snapshot of the day the change is applied on; `nil`
    /// keeps it. Only a merge and its inverse replace it.
    var progress: [DailySnapshot]?
    /// The deleted cards that replace `Deck.deletedCards`; `nil` keeps them in step with
    /// the removals and the cards that come back: those removed are noted `now`, those
    /// that come back dropped. Only a merge and its inverse replace them.
    var deletedCards: [Card.ID: Date]?
    /// The retired cards that replace `Deck.retiredCards`; `nil` keeps them in step with the
    /// removals and the cards that come back: a card removed that has a log is retired, a card
    /// that comes back leaves them. Only a merge and its inverse replace them.
    var retiredCards: [Card]?
    /// Whether the upserts replace only the learning of the cards the deck holds (`Card.takeLearning(from:)`)
    /// and leave a card it lacks out: a review and its inverse. The card may have changed since the
    /// review, e.g. its text by a merge, and undoing the review must not take that back, nor bring a
    /// card back that was deleted meanwhile.
    var learningOnly = false
    /// With `learningOnly`: the cards on which the change takes back or puts back one review instead of replacing
    /// the whole learning, see `ReviewEdit`. The inverse of a review takes back only that review, so reviews
    /// another device added to the card meanwhile stay.
    var reviewEdits: [Card.ID: ReviewEdit] = [:]
    /// Media files the deck takes in: those of an import or of a merge, or those a card's new
    /// media come in. Files the deck holds already stay as they are.
    var addedMedia = DeckMedia()
    /// Media files to take out: the inverse of the files a change brought in. One that a card
    /// still names stays.
    var removedMedia: Set<String> = []
    var contentStamp: ContentStamp

    /// One review of a card that a `learningOnly` change takes back or puts back; the card of the upsert is the card
    /// as it was before the review (`takeBack`) or after it (`putBack`), see `Card.takeBack(_:before:scheduler:)`.
    enum ReviewEdit: Sendable {
        case takeBack(ReviewLogEntry)
        case putBack(ReviewLogEntry)
    }

    /// What a change does to `Deck.contentModified` and `Deck.learningOptionsChanged`.
    enum ContentStamp: Sendable {
        /// Reviews and suspensions leave the content as it is.
        case keep
        /// A change to the content stamps the time it is applied, and so does its
        /// inverse: undoing a change changes the content, too. A card whose texts, note
        /// or kind change, or that comes back after its removal, gets the time as its
        /// `contentChanged`; new learning options get it as `learningOptionsChanged`.
        case now
        /// A merge takes the later stamp of both versions for each; its inverse
        /// restores the old ones.
        case set(Date?, learningOptions: Date?)
    }

    /// - Parameters:
    ///   - upserts: Cards that replace the cards with the same ID; cards with a new
    ///     ID are appended.
    ///   - contentStamp: `.now` unless the change leaves the content, like a review.
    init(upserts: [Card] = [], removals: [Card.ID] = [], learningOptions: LearningOptions? = nil, contentStamp: ContentStamp = .now) {
        self.upserts = upserts.map { ($0, nil) }
        self.removals = removals
        self.learningOptions = learningOptions
        self.contentStamp = contentStamp
    }
}

extension DeckChange {
    /// Appends `cards` to `deck`. Only new cards without a log whose ID `deck` doesn't
    /// hold yet are added, so adding never replaces a card; `nil` if that leaves none.
    public static func adding(_ cards: [Card], to deck: Deck) -> DeckChange? {
        var ids = Set(deck.cards.map(\.id))
        let added = cards.filter { $0.isNew && $0.log.isEmpty && ids.insert($0.id).inserted }
        return added.isEmpty ? nil : DeckChange(upserts: added)
    }

    /// Moves the new cards with `ids` in `deck` into the addition of the study day of `now`, as if they were added
    /// again, in the order of `ids`: they get `created` stamps a second apart that end at `now` in whole seconds,
    /// so the new cards come in that order and before every earlier addition (`StudySession`, newest addition
    /// first). A lesson's words that the deck holds already go first with the lesson that way. Cards that have
    /// been studied, have a log or are suspended stay out, and so does an ID `deck` doesn't hold; `nil` if that
    /// leaves none. Stamps that reach back past the start of the day put the first cards with the day before.
    public static func renewing(_ ids: [Card.ID], in deck: Deck, at now: Date) -> DeckChange? {
        var seen = Set<Card.ID>()
        let cards = ids.compactMap { id -> Card? in
            guard seen.insert(id).inserted, let card = deck.card(withID: id), card.isNew, card.log.isEmpty, !card.isSuspended else { return nil }
            return card
        }
        let last = now.timeIntervalSince1970.rounded(.down)
        let renewed = cards.enumerated().map { index, card in
            var card = card
            card.created = Date(timeIntervalSince1970: last - Double(cards.count - 1 - index))
            return card
        }
        return renewed.isEmpty ? nil : DeckChange(upserts: renewed)
    }

    /// `adding(_:to:)` and `renewing(_:in:at:)` in one change, one undo: the new words of a lesson and those of it
    /// the deck holds already but hasn't started.
    public static func adding(_ cards: [Card], to deck: Deck, renewing ids: [Card.ID], at now: Date) -> DeckChange? {
        let upserts = (renewing(ids, in: deck, at: now)?.upserts ?? []) + (adding(cards, to: deck)?.upserts ?? [])
        return upserts.isEmpty ? nil : DeckChange(upserts: upserts.map(\.card))
    }

    /// Removes the cards with `ids` from `deck`; `nil` if `deck` holds none of them.
    public static func removing(_ ids: Set<Card.ID>, from deck: Deck) -> DeckChange? {
        let removals = deck.cards.map(\.id).filter(ids.contains)
        return removals.isEmpty ? nil : DeckChange(removals: removals)
    }

    /// Sets the images and sounds of the card with `id` in `deck` to `media`, keeping its learning
    /// state; `files` are the media files that are new to the deck. A name that isn't of the form of
    /// `DeckMedia.name(for:fileExtension:)` reads as none. `nil` if `deck` doesn't hold the card, or
    /// the media stay and `files` brings nothing new.
    public static func settingMedia(_ media: CardMedia, of id: Card.ID, in deck: Deck, adding files: DeckMedia = DeckMedia()) -> DeckChange? {
        guard let card = deck.card(withID: id) else { return nil }
        var edited = card
        edited.media = media.checked
        var change = DeckChange(upserts: edited == card ? [] : [edited])
        change.addedMedia = files.missing(from: deck.media)
        return change.upserts.isEmpty && change.addedMedia.isEmpty ? nil : change
    }

    /// Replaces question, answer and hint of the card with `id` in `deck` by `text`,
    /// keeping its learning state; `nil` if `deck` doesn't hold it or the text stays.
    public static func editingText(of id: Card.ID, to text: CardText, in deck: Deck) -> DeckChange? {
        guard let card = deck.card(withID: id) else { return nil }
        var edited = card
        edited.question = text.question
        edited.answer = text.answer
        edited.hint = text.hint
        return edited == card ? nil : DeckChange(upserts: [edited])
    }

    /// Sets note and kind of the card with `id` in `deck`, keeping its learning state:
    /// how an existing card joins the cards of a word. `note` is trimmed and an empty one
    /// clears it; `nil` if `deck` doesn't hold the card or both stay.
    public static func settingNote(_ note: String?, kind: CardKind?, of id: Card.ID, in deck: Deck) -> DeckChange? {
        guard let card = deck.card(withID: id) else { return nil }
        var edited = card
        edited.note = Card.normalized(note)
        edited.kind = kind
        return edited == card ? nil : DeckChange(upserts: [edited])
    }

    /// Makes the cards with `ids` in `deck` new again, keeping their content, and notes
    /// `now` as their `learningStateReset`, so a merge leaves out the reviews before it.
    /// Cards that are new already and have no log stay out; `nil` if that leaves none.
    public static func resettingLearningState(of ids: Set<Card.ID>, in deck: Deck, at now: Date) -> DeckChange? {
        // Whole seconds, as `deck.json` stores dates, so the deck read back is the same.
        let reset = Date(timeIntervalSince1970: now.timeIntervalSince1970.rounded(.down))
        let cards = deck.cards.filter { ids.contains($0.id) && (!$0.isNew || !$0.log.isEmpty) }.map { card in
            var card = card
            card.resetLearningState()
            card.undone = []
            card.learningStateReset = reset
            return card
        }
        return cards.isEmpty ? nil : DeckChange(upserts: cards)
    }

    /// Suspends the cards with `ids` in `deck`, or resumes them if `suspended` is
    /// `false`, and notes `now` as their `suspensionChanged`; cards already so stay out,
    /// `nil` if that leaves none (#290).
    ///
    /// Leaves `Deck.contentModified` as it is: the iPhone suspends cards too, and a
    /// merge must not take the content from its version for that. It takes the flag of
    /// each card from the version that changed it last instead.
    public static func settingSuspended(_ suspended: Bool, of ids: Set<Card.ID>, in deck: Deck, at now: Date) -> DeckChange? {
        // Whole seconds, as `deck.json` stores dates, so the deck read back is the same.
        let changed = Date(timeIntervalSince1970: now.timeIntervalSince1970.rounded(.down))
        let cards = deck.cards.filter { ids.contains($0.id) && $0.isSuspended != suspended }.map { card in
            var card = card
            card.isSuspended = suspended
            card.suspensionChanged = changed
            return card
        }
        return cards.isEmpty ? nil : DeckChange(upserts: cards, contentStamp: .keep)
    }

    /// Sets the learning options of `deck`, clamped into the ranges they offer, or `nil`
    /// if that doesn't change them. New FSRS parameters also replay stability and
    /// difficulty of every card with a complete review log
    /// (`Scheduler.replayingMemory(of:)`); due dates stay.
    public static func changingLearningOptions(_ learningOptions: LearningOptions, in deck: Deck, calendar: StudyCalendar) -> DeckChange? {
        var learningOptions = learningOptions
        learningOptions.sanitize()
        guard deck.learningOptions != learningOptions else { return nil }
        var replayed: [Card] = []
        if learningOptions.parameters != deck.learningOptions.parameters {
            let scheduler = Scheduler(learningOptions: learningOptions, calendar: calendar)
            replayed = deck.cards.compactMap { card in
                guard let replayed = scheduler.replayingMemory(of: card), replayed != card else { return nil }
                return replayed
            }
        }
        return DeckChange(upserts: replayed, learningOptions: learningOptions)
    }
}

extension Deck {
    /// Applies `change` at `now` and returns the change that reverts it.
    ///
    /// A change to the cards records their distribution as the snapshot for the study
    /// day of `now`; learning options alone move no card between the bins of a
    /// snapshot. Applying the inverse records the snapshot again rather than restoring
    /// the old one. That holds when the inverse comes on a later study day, too, e.g.
    /// undoing a review the next morning: a snapshot shows the cards at the end of its
    /// day, and at the end of the earlier day the change was still in effect. So only
    /// the snapshot of that day changes, never an earlier one, except for a merge,
    /// which replaces the progress as a whole.
    public mutating func apply(_ change: DeckChange, at now: Date, calendar: StudyCalendar) -> DeckChange {
        var inverse = DeckChange(contentStamp: .keep)
        // Whole seconds, as `deck.json` stores dates.
        let stamp = Date(timeIntervalSince1970: now.timeIntervalSince1970.rounded(.down))
        let isContentChange: Bool

        switch change.contentStamp {
        case .keep:
            isContentChange = false
        case .now:
            isContentChange = true
            inverse.contentStamp = .now
            contentModified = stamp
            if change.learningOptions != nil {
                learningOptionsChanged = stamp
            }
        case let .set(date, learningOptionsDate):
            isContentChange = false
            inverse.contentStamp = .set(contentModified, learningOptions: learningOptionsChanged)
            contentModified = date
            learningOptionsChanged = learningOptionsDate
        }

        inverse.learningOnly = change.learningOnly

        if let deletedCards = change.deletedCards {
            inverse.deletedCards = self.deletedCards
            self.deletedCards = deletedCards
        }

        if let retiredCards = change.retiredCards {
            inverse.retiredCards = self.retiredCards
            self.retiredCards = retiredCards
        }

        if let learningOptions = change.learningOptions {
            inverse.learningOptions = self.learningOptions
            self.learningOptions = learningOptions
        }

        if let progress = change.progress {
            inverse.progress = self.progress
            self.progress = progress
        }

        let newMedia = change.addedMedia.missing(from: media)
        if !newMedia.isEmpty {
            media.formUnion(newMedia)
            inverse.removedMedia = newMedia.names
        }

        // Every step below passes over the cards once: a change may touch all of them.
        if !change.removals.isEmpty {
            let removals = Set(change.removals)
            // In ascending order, so the inverse re-inserts each card at its old index.
            inverse.upserts = cards.enumerated().filter { removals.contains($0.element.id) }.map { ($0.element, $0.offset) }
            cards.removeAll { removals.contains($0.id) }
            if change.deletedCards == nil {
                for id in removals {
                    deletedCards[id] = stamp
                }
            }
            if change.retiredCards == nil {
                // The reviews of a deleted card stay (`Deck.retiredCards`).
                retiredCards.append(contentsOf: inverse.upserts.map(\.card).filter { !$0.log.isEmpty })
            }
        }

        let scheduler = Scheduler(learningOptions: learningOptions, calendar: calendar)
        var indices = Dictionary(cards.enumerated().map { ($0.element.id, $0.offset) }) { first, _ in first }
        var insertions: [(card: Card, index: Int)] = []
        var comingBack = Set<Card.ID>()
        for (card, position) in change.upserts {
            var card = card
            if change.learningOnly {
                guard let index = indices[card.id] else { continue }
                let current = cards[index]
                inverse.upserts.append((current, nil))
                switch change.reviewEdits[card.id] {
                case let .takeBack(entry)?:
                    cards[index].takeBack(entry, before: card, scheduler: scheduler)
                    inverse.reviewEdits[card.id] = .putBack(entry)
                case let .putBack(entry)?:
                    cards[index].putBack(entry, after: card, scheduler: scheduler)
                    inverse.reviewEdits[card.id] = .takeBack(entry)
                case nil:
                    cards[index].takeLearning(from: card)
                    // A review adds one entry at the end of the log; undoing it takes back that one.
                    if let entry = card.log.last, card.log.count == current.log.count + 1, card.log.dropLast() == current.log[...] {
                        inverse.reviewEdits[card.id] = .takeBack(entry)
                    }
                }
                continue
            }
            if let index = indices[card.id] {
                if isContentChange, card.hasOtherContent(than: cards[index]) {
                    card.contentChanged = stamp
                }
                inverse.upserts.append((cards[index], nil))
                cards[index] = card
            } else if let position {
                // Only the inverse of a removal inserts at an index: the card is back,
                // later than its removal, which the other device may have taken in.
                if isContentChange {
                    card.contentChanged = stamp
                }
                insertions.append((card, position))
                inverse.removals.append(card.id)
            } else {
                indices[card.id] = cards.count
                cards.append(card)
                inverse.removals.append(card.id)
            }
            if change.deletedCards == nil {
                deletedCards[card.id] = nil
            }
            comingBack.insert(card.id)
        }
        if change.retiredCards == nil, !retiredCards.isEmpty, !comingBack.isEmpty {
            retiredCards.removeAll { comingBack.contains($0.id) }
        }
        if !insertions.isEmpty {
            cards = Self.inserting(insertions, into: cards)
        }

        if !change.removedMedia.isEmpty {
            // Cards are as they will be: a file a card still names stays, as undoing an import
            // must not take the file of a card that came later.
            let taken = media.remove(change.removedMedia.subtracting(namedMedia))
            if !taken.isEmpty {
                inverse.addedMedia = taken
            }
        }

        if !change.upserts.isEmpty || !change.removals.isEmpty || change.progress != nil {
            updateProgress(day: calendar.dayNumber(for: now))
        }
        return inverse
    }

    /// Inserts cards at their indices in one pass. Only the inverse of removals inserts
    /// at an index, in ascending order; each card lands where inserting the cards one
    /// after another would put it.
    private static func inserting(_ insertions: [(card: Card, index: Int)], into cards: [Card]) -> [Card] {
        assert(zip(insertions, insertions.dropFirst()).allSatisfy { $0.index < $1.index })
        var result: [Card] = []
        result.reserveCapacity(cards.count + insertions.count)
        var remaining = cards[...]
        for (card, index) in insertions {
            let count = min(index - result.count, remaining.count)
            result.append(contentsOf: remaining.prefix(count))
            remaining = remaining.dropFirst(count)
            result.append(card)
        }
        result.append(contentsOf: remaining)
        return result
    }
}
