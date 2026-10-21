import SwiftUI

/// The sheet of Today's Add Cards: opens the deck the cards go to and shows `AddCardsSheet`
/// once the deck is read and can be changed. Before that it shows a spinner, or why the deck
/// could not be opened. `StartScreen` closes the deck when the sheet has gone.
struct AddCardsHost: View {
    var deck: OpenDeck
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if let document = deck.document, deck.isEditable, document.isReadyToEdit {
            AddCardsSheet(document: document)
                .background { DocumentAttachment(document: document, deck: deck) }
        } else {
            StudyPlaceholder(failure: deck.failure) { dismiss() }
        }
    }
}
