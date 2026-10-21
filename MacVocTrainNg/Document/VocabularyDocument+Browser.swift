import Foundation
import VocabCore

/// The changes of the card browser that `VocabularyDocument+Editing.swift` has no method for.
extension VocabularyDocument {
    /// Sets the word key of a card, see `DeckChange.settingNote(_:kind:of:in:)`: the card
    /// keeps its kind and its learning state, and an empty key clears the key. Changes
    /// nothing while the document can't be changed or the key stays.
    ///
    /// Registers with the name of the edit sheet's other change, `editText(of:to:)`: saved
    /// together, as the sheet does, both are one undo action.
    func setNote(_ note: String?, of id: Card.ID) {
        guard isReadyToEdit, let card = card(withID: id),
            let change = DeckChange.settingNote(note, kind: card.kind, of: id, in: deck)
        else { return }
        perform(change, actionName: String(localized: "Edit Card"))
    }
}
