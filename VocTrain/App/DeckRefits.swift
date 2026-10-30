import Foundation
import VocabCore

/// The automatic refit of FSRS parameters on the iPhone (`ParameterRefit`): after launch, once
/// nothing is on the screen but Today, the known decks are read from their files, off the main
/// actor, and each is fitted on the reviews of all of them if it is due. A deck with something to apply is opened as a document
/// (`OpenDeck`), changed through its editing layer (`applyParameterRefit`) and closed, which
/// saves it.
///
/// One deck at a time (`ParameterRefitter`), and never while the learner has anything open:
/// `isIdle` is asked before each deck and again before its result is applied.
@MainActor
enum DeckRefits {
    static func run(_ decks: [URL], isIdle: @MainActor () -> Bool) async {
        // Read once: the reviews of every deck are the log each deck is fitted on, and each deck's own options say whether it is due.
        let (known, pool) = await Task.detached(priority: .utility) { () -> ([(url: URL, options: LearningOptions)], [Card]) in
            let read = decks.compactMap { url in DeckFileReader.deck(at: url).map { (url: url, deck: $0) } }
            return (read.map { (url: $0.url, options: $0.deck.learningOptions) }, read.flatMap { $0.deck.trainingCards })
        }.value
        for (url, options) in known {
            guard !Task.isCancelled, isIdle() else { return }
            await ParameterRefitter.run(
                fit: { try ParameterRefit.fit(cards: pool, options: options, calendar: StudyCalendar(), now: Date()) },
                canApply: isIdle,
                apply: { await apply($0, toDeckAt: url) })
        }
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
        await UnsavedDecks.close(deck)
    }
}
