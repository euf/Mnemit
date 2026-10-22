import Foundation
import VocabCore

/// The automatic refit of FSRS parameters on the iPhone (`ParameterRefit`): after launch, once
/// nothing is on the screen but Today, each known deck is read from its file, off the main
/// actor, and fitted if it is due. A deck with something to apply is opened as a document
/// (`OpenDeck`), changed through its editing layer (`applyParameterRefit`) and closed, which
/// saves it.
///
/// One deck at a time (`ParameterRefitter`), and never while the learner has anything open:
/// `isIdle` is asked before each deck and again before its result is applied.
@MainActor
enum DeckRefits {
    static func run(_ decks: [URL], isIdle: @MainActor () -> Bool) async {
        for url in decks {
            guard !Task.isCancelled, isIdle() else { return }
            await ParameterRefitter.run(
                fit: { try fit(deckAt: url) },
                canApply: isIdle,
                apply: { await apply($0, toDeckAt: url) })
        }
    }

    /// `nil` for a deck that can't be read now, or is not due.
    nonisolated static func fit(deckAt url: URL) throws -> ParameterRefit.Result? {
        guard let deck = DeckFileReader.deck(at: url) else { return nil }
        return try ParameterRefit.fit(cards: deck.cards, options: deck.learningOptions, calendar: StudyCalendar(), now: Date())
    }

    /// Opens the deck, applies `result` as the undo step "Update Parameters" and saves. A
    /// deck that fails to open, or is not editable in half a minute, is left alone: it is due
    /// again at the next launch.
    static func apply(_ result: ParameterRefit.Result, toDeckAt url: URL) async {
        let deck = OpenDeck(url: url)
        if let document = await deck.editableDocument() {
            document.applyParameterRefit(result)
            await deck.settleChanges()
        }
        await deck.close()
    }
}
