import Foundation
import VocabCore

/// The changes of a deck beyond studying and suspending: adding, editing, deleting and
/// resetting cards, and the learning options. The Mac app and the iPhone app make them
/// the same way (#297). Each goes through `perform(_:actionName:alongside:)`, which
/// registers its undo action with the document's undo manager, so the document counts as
/// changed, and the `VersionMerger` of the window or scene saves it soon after. Nothing
/// changes until the document `isReadyToEdit` (#305); the iPhone app also checks
/// `OpenDeck.isEditable` before it offers an edit.
///
/// A device that edits cards doesn't take another device's edits away: see
/// `DeckChange.merging(_:into:calendar:)` for what each part of a deck does when two
/// versions meet.
extension VocabularyDocument {
    /// Appends a new card with `text`, created now by the document's clock, see
    /// `DeckChange.adding(_:to:)`. Returns the ID of the new card, `nil` while the
    /// document can't be changed.
    @discardableResult
    func add(_ text: CardText) -> Card.ID? {
        guard isReadyToEdit else { return nil }
        let card = Card(text: text, created: clock.now)
        if let change = DeckChange.adding([card], to: deck) {
            perform(change, actionName: String(localized: "Add Card"))
        }
        return card.id
    }

    /// Appends new `cards` as one change, one undo: the two directions of a word, say.
    /// Cards the deck holds already, or that have been studied, stay out. Returns the
    /// number of cards added, 0 while the document can't be changed.
    @discardableResult
    func add(_ cards: [Card]) -> Int {
        guard isReadyToEdit, let change = DeckChange.adding(cards, to: deck) else { return 0 }
        let before = deck.cards.count
        perform(change, actionName: cards.count == 1 ? String(localized: "Add Card") : String(localized: "Add Cards"))
        return deck.cards.count - before
    }

    /// Appends cards from an import as one change, one undo, with the learning state and the
    /// review log they come with, see `DeckChange.importing(_:into:)`: those of an Anki package
    /// bring their history.
    func importCards(_ cards: [Card]) {
        guard isReadyToEdit, let change = DeckChange.importing(cards, into: deck) else { return }
        perform(change, actionName: String(localized: "Import Cards"))
    }

    /// Appends the cards of lesson words, see `LessonWords`, as one change: one undo takes
    /// all of them back. Returns the number of cards added, 0 while the document can't be
    /// changed.
    @discardableResult
    func addLessonCards(_ cards: [Card]) -> Int {
        guard isReadyToEdit, let change = DeckChange.adding(cards, to: deck) else { return 0 }
        perform(change, actionName: String(localized: "Add Lesson Words"))
        return cards.count
    }

    /// Changes question, answer and hint of a card, see `DeckChange.editingText(of:to:in:)`.
    func editText(of id: Card.ID, to text: CardText) {
        guard isReadyToEdit, let change = DeckChange.editingText(of: id, to: text, in: deck) else { return }
        perform(change, actionName: String(localized: "Edit Card"))
    }

    /// Changes question, answer and hint of a card and its word key (`Card.note`) in one
    /// undo step, as the edit sheet saves them; the kind stays.
    func editCard(_ id: Card.ID, text: CardText, note: String?) {
        guard isReadyToEdit else { return }
        // The second change reads the card the first one leaves, or it would put the old
        // text back.
        var edited = deck
        var changes: [DeckChange] = []
        if let change = DeckChange.editingText(of: id, to: text, in: edited) {
            _ = edited.apply(change, at: clock.now, calendar: calendar)
            changes.append(change)
        }
        if let change = DeckChange.settingNote(note, kind: edited.card(withID: id)?.kind, of: id, in: edited) {
            changes.append(change)
        }
        guard !changes.isEmpty else { return }
        perform(changes, actionName: String(localized: "Edit Card"))
    }

    /// Sets the word key and the kind of a card, see `DeckChange.settingNote(_:kind:of:in:)`:
    /// how an existing card joins the cards of a word. `note` is trimmed, and an empty one
    /// clears it.
    func setNote(_ note: String?, kind: CardKind?, of id: Card.ID) {
        guard isReadyToEdit, let change = DeckChange.settingNote(note, kind: kind, of: id, in: deck) else { return }
        perform(change, actionName: String(localized: "Edit Card"))
    }

    /// Sets which direction a card asks, `nil` for none; its word key stays.
    func setKind(_ kind: CardKind?, of id: Card.ID) {
        guard let card = deck.card(withID: id) else { return }
        setNote(card.note, kind: kind, of: id)
    }

    func delete(_ ids: Set<Card.ID>) {
        guard isReadyToEdit, let change = DeckChange.removing(ids, from: deck) else { return }
        let name = ids.count == 1 ? String(localized: "Delete Card") : String(localized: "Delete Cards")
        perform(change, actionName: name)
    }

    func resetLearningState(of ids: Set<Card.ID>) {
        guard isReadyToEdit, let change = DeckChange.resettingLearningState(of: ids, in: deck, at: clock.now) else { return }
        perform(change, actionName: String(localized: "Reset Learning State"))
    }

    /// Changes the learning options, see `DeckChange.changingLearningOptions(_:in:calendar:)`.
    func updateLearningOptions(_ learningOptions: LearningOptions) {
        guard isReadyToEdit, let change = DeckChange.changingLearningOptions(learningOptions, in: deck, calendar: calendar) else { return }
        perform(change, actionName: String(localized: "Change Learning Options"))
    }

    /// Applies what the automatic refit found, see `ParameterRefit`: the new parameters, if
    /// they are kept, and the note of the attempt, to the learning options as they are now.
    /// One undo step, named like the change of the parameters it is. A deck that has moved on
    /// since the fit began is left as it is: the learner switched the update off, or another
    /// device fitted it later.
    func applyParameterRefit(_ result: ParameterRefit.Result) {
        let options = deck.learningOptions
        guard isReadyToEdit, options.updatesParametersAutomatically,
            options.lastAutoFit.map({ $0.date < result.fit.date }) ?? true,
            let change = DeckChange.changingLearningOptions(result.applied(to: options), in: deck, calendar: calendar)
        else { return }
        perform(change, actionName: String(localized: "Update Parameters"))
    }
}
