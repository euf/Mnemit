import SwiftUI

/// The sheet of Today's Add Cards and Import: opens the deck the cards go to and shows
/// `AddCardsSheet`, or `ImportPreviewSheet` for the `file` of Import, once the deck is read and
/// can be changed. Before that it shows a spinner, or why the deck could not be opened.
/// `StartScreen` closes the deck when the sheet has gone.
struct AddCardsHost: View {
    var deck: OpenDeck
    /// The file whose cards the sheet offers to import; `nil` for Add Cards.
    var file: ImportedFile?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if let document = deck.document, deck.isEditable, document.isReadyToEdit {
            Group {
                if let file {
                    ImportPreviewSheet(document: document, file: file)
                } else {
                    AddCardsSheet(document: document)
                }
            }
            .background { DocumentAttachment(document: document, deck: deck) }
        } else {
            StudyPlaceholder(failure: deck.failure) { dismiss() }
        }
    }
}
