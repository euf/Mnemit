import SwiftUI
import VocabCore

/// The screen of a route, built from the deck its slot holds. Reads the slot itself, so the
/// screen follows when the deck is opened again in it, as after a rename.
struct PushedDeckView<Content: View>: View {
    var pushed: PushedDecks
    var slot: PushedDecks.Slot
    @ViewBuilder var content: (OpenDeck) -> Content

    var body: some View {
        if let deck = pushed.deck(slot) {
            content(deck)
        }
    }
}

/// A card found by the search of Today: its screen, once the deck is read.
struct CardHost: View {
    var deck: OpenDeck
    var id: Card.ID
    /// Opens the deck again after it could not be opened.
    var retry: () -> Void = {}

    var body: some View {
        if let document = deck.document {
            CardDetailScreen(document: document, cardID: id, canEdit: deck.isEditable)
                .background { DocumentAttachment(document: document, deck: deck) }
        } else if let failure = deck.failure {
            ContentUnavailableView {
                Label("The deck could not be opened", systemImage: "exclamationmark.triangle")
            } description: {
                Text(failure)
            } actions: {
                Button("Try Again", action: retry)
                    .buttonStyle(.borderedProminent)
            }
        } else {
            ProgressView()
        }
    }
}
