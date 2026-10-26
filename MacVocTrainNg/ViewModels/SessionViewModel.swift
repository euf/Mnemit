import AppKit
import Combine
import Foundation
import Observation
import VocabCore

/// Drives the study stream on the Mac: the learner reveals the answer and grades it. The stream
/// itself is the iPhone's `StudyModel`: one deck, or every deck of the day at once, each card from the
/// deck whose next card is most urgent, with the rounds, Push On and Undo across the decks; applying
/// grades and keeping the stream's place in step with undo and redo is left to its `SessionDriver`s.
@MainActor @Observable
final class SessionViewModel {
    /// Asking, answer shown, or at rest.
    typealias Stage = StudyModel.Stage

    /// What the stream starts with, as on the iPhone.
    typealias Entry = StudyModel.Entry

    private let stream: StudyModel
    /// Tells the stream when the application stops being active: the time away is not on a card.
    @ObservationIgnored private var activityObservation: AnyCancellable?

    /// A stream over `document` alone.
    convenience init(document: VocabularyDocument, entry: Entry = .study, rounds: RoundGuide? = nil, ring: DailyRingModel? = nil) {
        self.init(documents: [document], entry: entry, rounds: rounds, ring: ring)
    }

    /// A stream over `documents`, the decks of the day; a practice takes the first only. The rounds are `rounds`
    /// (tests), or follow `ring`.
    init(documents: [VocabularyDocument], entry: Entry = .study, rounds: RoundGuide? = nil, ring: DailyRingModel? = nil) {
        stream = StudyModel(documents: documents, entry: entry, rounds: rounds, ring: ring)
        let center = NotificationCenter.default
        activityObservation = center.publisher(for: NSApplication.didBecomeActiveNotification).map { _ in true }
            .merge(with: center.publisher(for: NSApplication.didResignActiveNotification).map { _ in false })
            .sink { [weak self] in self?.stream.setActive($0) }
    }

    /// The deck of the card asked now: the one a grade goes to, and Edit Card edits.
    var document: VocabularyDocument { stream.document }

    /// Counts the questions asked; the view speaks a Greek question when it changes.
    var questionNumber: Int { stream.questionNumber }

    var stage: Stage {
        if stream.isResting { return .resting }
        return stream.stage == .revealed ? .revealed : .asking
    }

    /// The segment running; its mode decides how a review is recorded.
    var mode: SessionMode { stream.mode }

    /// The part of the segment that study and practice share.
    var session: Session { stream.session }

    /// Where the stream is: today's plan, practice, or at rest.
    var streamStage: StudyStream.Stage { stream.streamStage }

    /// The card being asked, as the deck holds it now. Undoing an edit of the card
    /// during the session shows up here.
    var currentCard: Card? { stream.currentCard }

    var isPracticing: Bool { stream.isPracticing }

    var isResting: Bool { stage == .resting }

    /// What the stream shows at rest.
    var rest: StreamRest { stream.rest }

    /// Goes on with the next round, from the rest at the end of one.
    func continueRound() {
        stream.continueRound()
    }

    /// Push On: adds 10 new cards beyond the daily limits to the stack that is done for the day, from the decks in turn.
    func addNewCards() {
        stream.addNewCards()
    }

    /// The cards of the current round waiting behind the one asked, as the iPhone's stack shows them; 0 without
    /// rounds, in practice and once the goal is met.
    var cardsBehind: Int { stream.cardsBehind }

    /// The new cards `addNewCards()` would add; `nil` if there are none and for a practice.
    var extraNew: ExtraNewCards? { stream.extraNew }

    /// What the last grade did, shown in the chip that offers Undo.
    var receipt: GradeReceipt? { stream.lastReceipt }

    func dismissReceipt() {
        stream.dismissReceipt()
    }

    /// Whether Z, Esc and the chip can take back the last review or suspension, whichever deck it was in.
    var canUndoLast: Bool { stream.canUndo }

    /// Takes back the last review or suspension of the stream, in its own deck.
    func undoLast() {
        guard canUndoLast else { return }
        stream.undoLast()
    }

    /// Shows the answer.
    func reveal() {
        guard stage == .asking else { return }
        stream.reveal()
    }

    /// Only once the answer is shown.
    func grade(_ grade: Grade) {
        guard stage == .revealed else { return }
        stream.grade(grade)
    }

    /// Suspends the card being asked, so no session asks it until the learner resumes
    /// it in the card list, and moves on (#290). ⌘Z takes it back like a review.
    func suspendCurrentCard() {
        guard stage != .resting, currentCard != nil else { return }
        stream.suspendCurrentCard()
    }
}
