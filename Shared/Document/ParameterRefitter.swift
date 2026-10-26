import Foundation
import VocabCore

/// Runs the automatic refit of a deck's FSRS parameters for both apps, see `ParameterRefit`
/// for when a deck is due and what is kept. This is the part that costs: the optimizer runs
/// off the main actor at background priority, one deck at a time in the whole app, and the
/// result goes to the deck through the document's editing layer, which makes it one undo
/// step and merges it between devices like any other change of the options.
///
/// A deck the learner is studying is never touched: `canApply` is asked before the fit starts
/// and again when it is done, and a fit that ends during a study stream is dropped. The deck
/// is due again at the next opening.
@MainActor
enum ParameterRefitter {
    /// Fits `document`'s deck if it is due and applies the result.
    ///
    /// - Parameter canApply: `false` while something stands in the way of changing the deck:
    ///   the Mac's study stream.
    static func refit(_ document: VocabularyDocument, canApply: @MainActor () -> Bool = { true }) async {
        let deck = document.deck
        let calendar = document.calendar
        let now = document.clock.now
        guard deck.learningOptions.updatesParametersAutomatically else { return }
        await run(
            fit: { try ParameterRefit.fit(cards: deck.trainingCards, options: deck.learningOptions, calendar: calendar, now: now) },
            canApply: { document.isReadyToEdit && canApply() },
            apply: { document.applyParameterRefit($0) })
    }

    /// Waits for its turn, then runs `fit` in the background; if that finds something and
    /// `canApply` still says yes, hands it to `apply`.
    static func run(
        fit: @escaping @Sendable () throws -> ParameterRefit.Result?,
        canApply: @MainActor () -> Bool,
        apply: @MainActor (ParameterRefit.Result) async -> Void
    ) async {
        await turn.enter()
        defer { turn.leave() }
        guard !Task.isCancelled, canApply() else { return }

        let work = Task.detached(priority: .background) { try fit() }
        let result = try? await withTaskCancellationHandler {
            try await work.value
        } onCancel: {
            work.cancel()
        }
        guard !Task.isCancelled, let result, canApply() else { return }
        await apply(result)
    }

    /// One fit at a time, in the order they ask: several windows opened together, or the
    /// decks of the iPhone one after the other.
    private static let turn = Turn()

    @MainActor
    private final class Turn {
        private var isTaken = false
        private var waiting: [CheckedContinuation<Void, Never>] = []

        func enter() async {
            guard isTaken else {
                isTaken = true
                return
            }
            await withCheckedContinuation { waiting.append($0) }
        }

        func leave() {
            if waiting.isEmpty {
                isTaken = false
            } else {
                waiting.removeFirst().resume()
            }
        }
    }
}
