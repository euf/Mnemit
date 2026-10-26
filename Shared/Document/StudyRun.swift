import Foundation
import Observation
import VocabCore

/// One go at studying that covers the screen: one stream over the decks of the run. Study on
/// Today opens every deck with cards today and the stream takes each card from the deck whose next
/// card is most urgent (`StudyModel`); Study This Deck runs over one deck.
@MainActor @Observable
final class StudyRun {
    /// What the stream starts with; a practice takes the first deck only.
    let entry: StudyModel.Entry
    /// The decks of the run: the one it starts with, then the others with cards today.
    let decks: [OpenDeck]
    /// The decks the run closes with `close()`: those it opened itself, and the first one if it `ownsDeck`.
    let owned: [OpenDeck]

    /// - Parameters:
    ///   - ownsDeck: Whether the run closes `deck`. A run started from a Deck screen
    ///     studies the deck the screen holds open, which the screen closes.
    ///   - open: Gives the run the deck of each of the `upcoming` files. Without it the run
    ///     opens them itself and closes them; the decks `open` gives belong to the caller, as
    ///     on the Mac, where every deck stays open until the app quits.
    init(deck: OpenDeck, entry: StudyModel.Entry = .study, upcoming: [URL] = [], ownsDeck: Bool = true, open: ((URL) -> OpenDeck)? = nil) {
        let others = upcoming.map { open?($0) ?? OpenDeck(url: $0) }
        decks = [deck] + others
        owned = (ownsDeck ? [deck] : []) + (open == nil ? others : [])
        self.entry = entry
    }

    /// The deck the run starts with.
    var deck: OpenDeck { decks[0] }

    /// Whether the run closes the deck it starts with.
    var ownsDeck: Bool { owned.contains(deck) }

    /// Saves what is unsaved and lets go of the decks the run owns.
    func close() async {
        for deck in owned {
            await deck.close()
        }
    }
}

extension StudyRun: Identifiable, Hashable {
    nonisolated static func == (lhs: StudyRun, rhs: StudyRun) -> Bool {
        lhs === rhs
    }

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}
