import Foundation
import Observation
import VocabCore

/// Where a push on Today leads. A route names the deck by the slot `PushedDecks` holds it
/// in, not by its file: renaming the deck then changes the file and leaves the route.
enum DeckRoute: Hashable {
    case deck(PushedDecks.Slot)
    /// A card found by the search of Today.
    case card(PushedDecks.Slot, Card.ID)

    var slot: PushedDecks.Slot {
        switch self {
        case let .deck(slot), let .card(slot, _): slot
        }
    }
}

/// The decks that the screens pushed on Today hold open, one `OpenDeck` per deck that
/// has a Deck screen or a found card on the stack. The stack is the owner: a deck is opened
/// when its route is pushed (`open(_:)`) and closed when the route has gone from the path
/// (`close(except:)`), so the screens above it, the card browser, a card and the options,
/// all show the same document, and what they change is saved once, when the deck closes.
///
/// A closed deck stays in its slot until the next `open(_:)`: the screen that was popped is
/// still on the glass for the length of the animation, and takes the deck away from under it
/// otherwise.
@MainActor @Observable
final class PushedDecks {
    typealias Slot = UUID

    private(set) var decks: [Slot: OpenDeck] = [:]
    @ObservationIgnored private var closed: Set<Slot> = []

    /// Opens the deck at `url` in a new slot.
    func open(_ url: URL) -> Slot {
        for slot in closed {
            decks[slot] = nil
        }
        closed = []
        let slot = Slot()
        decks[slot] = OpenDeck(url: url)
        return slot
    }

    func deck(_ slot: Slot) -> OpenDeck? {
        decks[slot]
    }

    /// Closes the deck of `slot`, which saves what it holds.
    func close(_ slot: Slot) async {
        guard !closed.contains(slot), let deck = decks[slot] else { return }
        closed.insert(slot)
        await deck.close()
    }

    /// Closes the decks of every slot but `live`: the routes that have gone from the path.
    func close(except live: Set<Slot>) async {
        for slot in decks.keys where !live.contains(slot) {
            await close(slot)
        }
    }

    /// Opens the deck of `slot` again, at `url`: the deck was renamed, or the rename failed.
    func reopen(_ slot: Slot, at url: URL) {
        decks[slot] = OpenDeck(url: url)
        closed.remove(slot)
    }

    /// The decks that are open.
    var openDecks: [OpenDeck] {
        decks.filter { !closed.contains($0.key) }.map(\.value)
    }

    /// Lets go of the files while the app is in the background, saving what is unsaved.
    func suspend() {
        for deck in openDecks {
            deck.suspend()
        }
    }

    func resume() {
        for deck in openDecks {
            deck.resume()
        }
    }
}
