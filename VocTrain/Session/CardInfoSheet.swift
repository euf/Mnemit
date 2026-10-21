import SwiftUI
import VocabCore

/// What the app knows about a card, in a sheet: the card's own screen (`CardDetailScreen`),
/// opened by a long press on the card of the study stream, before or after the answer shows.
/// The card can be edited, suspended, reset or deleted from here; the stream follows, see
/// `SessionDriver`.
struct CardInfoSheet: View {
    var document: VocabularyDocument
    var card: Card

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            CardDetailScreen(document: document, cardID: card.id, canEdit: true)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(role: .close) { dismiss() }
                    }
                }
        }
        .presentationDetents([.medium, .large])
    }
}
