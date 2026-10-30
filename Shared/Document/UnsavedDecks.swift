import Foundation

/// The decks that held changes they could not save when the screen that opened them let go. A deck that is let go of is
/// gone with its changes, and its save is tried again only while it lives, so a deck whose close failed
/// waits here, saves on its own every half minute, and is closed once it has (`retry()`).
@MainActor
enum UnsavedDecks {
    private(set) static var decks: [OpenDeck] = []

    /// Saves what `deck` holds and lets go of it, as `OpenDeck.close()`; if it can't save, the deck is kept here
    /// with its changes and this returns `false`.
    @discardableResult
    static func close(_ deck: OpenDeck) async -> Bool {
        if await deck.close() {
            decks.removeAll { $0 === deck }
            return true
        }
        if !decks.contains(where: { $0 === deck }) { decks.append(deck) }
        return false
    }

    /// Closes again the decks kept here, which saves them if the disk is back.
    static func retry() async {
        for deck in decks {
            await close(deck)
        }
    }
}
