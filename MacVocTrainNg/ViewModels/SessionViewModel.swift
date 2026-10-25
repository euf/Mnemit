import AppKit
import Combine
import Foundation
import Observation
import VocabCore

/// Drives the study stream on the Mac: checks responses and moves on after a correct one
/// if asked to. With flash cards (`studyBy`) there is no response to check: the learner
/// reveals the answer and grades it. The stream itself is the iPhone's `StudyModel`: one
/// deck, or every deck of the day at once, each card from the deck whose next card is most
/// urgent, with the rounds, Push On and Undo across the decks; applying grades and keeping the
/// stream's place in step with undo and redo is left to its `SessionDriver`s.
@MainActor @Observable
final class SessionViewModel {
    enum Stage: Equatable {
        /// Waiting for the response to the current card.
        case asking
        /// Flash cards: the answer is shown; waiting for a grade.
        case revealed
        /// The response was checked; waiting for the learner to confirm a grade.
        case feedback(CheckResult, response: String)
        /// The stream waits for the learner, see `StudyStream.Stage.rest`.
        case resting
    }

    /// What the stream starts with, as on the iPhone.
    typealias Entry = StudyModel.Entry

    /// The card reviewed or suspended last, shown below the current one.
    struct PreviousReview: Equatable {
        var question: String
        var answer: String
        /// `nil` if the learner suspended the card instead (#290).
        var grade: Grade?
    }

    /// Move on right after a correct response instead of asking for a grade.
    let autoAdvance: Bool
    /// How the stream asks its cards.
    let studyBy: Preferences.StudyBy
    private let stream: StudyModel
    /// Tells the stream when the application stops being active: the time away is not on a card.
    @ObservationIgnored private var activityObservation: AnyCancellable?
    private(set) var previous: PreviousReview?
    var input = ""
    /// The response checked, with the question it was checked on.
    private var checked: (question: Int, result: CheckResult, response: String)?

    /// A stream over `document` alone.
    convenience init(
        document: VocabularyDocument, autoAdvance: Bool = Preferences.autoAdvance, studyBy: Preferences.StudyBy = .typing, entry: Entry = .study,
        rounds: RoundGuide? = nil, ring: DailyRingModel? = nil
    ) {
        self.init(documents: [document], autoAdvance: autoAdvance, studyBy: studyBy, entry: entry, rounds: rounds, ring: ring)
    }

    /// A stream over `documents`, the decks of the day; a practice takes the first only. The rounds are `rounds`
    /// (tests), or follow `ring`.
    init(
        documents: [VocabularyDocument], autoAdvance: Bool = Preferences.autoAdvance, studyBy: Preferences.StudyBy = .typing,
        entry: Entry = .study, rounds: RoundGuide? = nil, ring: DailyRingModel? = nil
    ) {
        self.autoAdvance = autoAdvance
        self.studyBy = studyBy
        stream = StudyModel(documents: documents, entry: entry, rounds: rounds, ring: ring, reviewMode: studyBy == .flashcards ? .revealed : .typed)
        stream.onMoveOn = { [weak self] in
            guard let self else { return }
            input = ""
            checked = nil
            // Undo or redo, from the menu or here: the bar of the last answer no longer says what happened.
            if stream.returnedByUndo { previous = nil }
        }
        // A checked response is checked again against the card as it is now, e.g. after undoing an edit of its answer.
        stream.onCardChange = { [weak self] in
            guard let self, let checked, checked.question == stream.questionNumber, let card = currentCard else { return }
            self.checked = (checked.question, checker.check(checked.response, against: card.answer), checked.response)
        }
        let center = NotificationCenter.default
        activityObservation = center.publisher(for: NSApplication.didBecomeActiveNotification).map { _ in true }
            .merge(with: center.publisher(for: NSApplication.didResignActiveNotification).map { _ in false })
            .sink { [weak self] in self?.stream.setActive($0) }
    }

    /// The deck of the card asked now: the one a grade goes to, and Edit Card edits.
    var document: VocabularyDocument { stream.document }

    /// Counts the questions asked. The view gives each question a response field of
    /// its own, so ⌘Z can't reach the typing for an earlier one (#9).
    var questionNumber: Int { stream.questionNumber }

    var stage: Stage {
        if stream.isResting { return .resting }
        if let checked, checked.question == stream.questionNumber { return .feedback(checked.result, response: checked.response) }
        return studyBy == .flashcards && stream.stage == .revealed ? .revealed : .asking
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
        previous = nil
    }

    var suggestedGrade: Grade? {
        guard case let .feedback(result, _) = stage else { return nil }
        return result.suggestedGrade
    }

    /// The answer with what an almost correct response got wrong marked; `nil` for any
    /// other stage or result. Minds case only where the check did.
    var highlightedAnswer: [ResponseDiff.Segment]? {
        guard case let .feedback(.almostCorrect, response) = stage, let card = currentCard else { return nil }
        return ResponseDiff.segments(response: response, expected: card.answer, caseSensitive: checker.caseSensitive)
    }

    /// Checks responses with the learning options of the card's deck.
    private var checker: ResponseChecker {
        ResponseChecker(caseSensitive: document.deck.learningOptions.caseSensitive)
    }

    /// Checks the response. An empty response counts as "I don't know".
    func submit() {
        guard stage == .asking, studyBy == .typing, let card = currentCard else { return }
        let result = checker.check(input, against: card.answer)
        if result == .correct, autoAdvance {
            grade(.good)
        } else {
            checked = (stream.questionNumber, result, input)
        }
    }

    /// Flash cards: shows the answer.
    func reveal() {
        guard studyBy == .flashcards, stage == .asking else { return }
        stream.reveal()
    }

    /// With flash cards only once the answer is shown.
    func grade(_ grade: Grade) {
        guard stage != .resting, studyBy == .typing || stage == .revealed, let card = currentCard else { return }
        // A typed response is its own reveal.
        if studyBy == .typing { stream.reveal() }
        guard stream.grade(grade) != nil else { return }
        previous = PreviousReview(question: card.question, answer: card.answer, grade: grade)
    }

    /// Suspends the card being asked, so no session asks it until the learner resumes
    /// it in the card list, and moves on (#290). ⌘Z takes it back like a review.
    func suspendCurrentCard() {
        guard stage != .resting, let card = currentCard else { return }
        let asked = stream.questionNumber
        stream.suspendCurrentCard()
        if stream.questionNumber != asked {
            previous = PreviousReview(question: card.question, answer: card.answer, grade: nil)
        }
    }
}
