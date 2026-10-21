import Foundation
import Observation
import VocabCore

/// Drives a session on the Mac: checks responses, moves on after a correct one if
/// asked to, practises the mistakes and finishes up. With flash cards (`studyBy`) there
/// is no response to check: the learner reveals the answer and grades it. Applying
/// grades and keeping the session's place in step with undo and redo and with every
/// other change to the deck is left to a `SessionDriver`, which the iPhone app shares.
@MainActor @Observable
final class SessionViewModel {
    enum Stage: Equatable {
        /// Waiting for the response to the current card.
        case asking
        /// Flash cards: the answer is shown; waiting for a grade.
        case revealed
        /// The response was checked; waiting for the learner to confirm a grade.
        case feedback(CheckResult, response: String)
        case finished
    }

    /// The card reviewed or suspended last, shown below the current one.
    struct PreviousReview: Equatable {
        var question: String
        var answer: String
        /// `nil` if the learner suspended the card instead (#290).
        var grade: Grade?
    }

    let document: VocabularyDocument
    /// Move on right after a correct response instead of asking for a grade.
    let autoAdvance: Bool
    /// How this session, its practice and the sessions after it ask their cards.
    let studyBy: Preferences.StudyBy
    private let driver: SessionDriver
    private(set) var stage: Stage
    private(set) var previous: PreviousReview?
    /// Counts the questions asked. The view gives each question a response field of
    /// its own, so ⌘Z can't reach the typing for an earlier one (#9).
    private(set) var questionNumber = 0
    var input = ""

    /// Uses the document's clock, so reviews and the snapshot they update fall on the same study day.
    /// Types by default, so a test doesn't depend on the learner's preference; the app passes it.
    init(document: VocabularyDocument, autoAdvance: Bool = Preferences.autoAdvance, studyBy: Preferences.StudyBy = .typing) {
        let study = Self.makeStudySession(for: document, studyBy: studyBy)
        self.document = document
        self.autoAdvance = autoAdvance
        self.studyBy = studyBy
        driver = SessionDriver(document: document, mode: .study(study))
        stage = study.session.isFinished ? .finished : .asking
        driver.delegate = self
    }

    /// The running session; its mode decides how a review is recorded.
    var mode: SessionMode { driver.mode }

    /// The part of the session that study sessions and practice share.
    var session: Session { driver.session }

    /// The card being asked, as the deck holds it now. Undoing an edit of the card
    /// during the session shows up here.
    var currentCard: Card? { driver.currentCard }

    var isPracticing: Bool {
        if case .practice = mode { true } else { false }
    }

    var isFinished: Bool { stage == .finished }

    /// What the last grade did, shown in the chip that offers Undo.
    var receipt: GradeReceipt? { driver.lastReceipt }

    func dismissReceipt() {
        driver.dismissReceipt()
    }

    /// Whether Z, Esc and the chip can take back the review or suspension shown below the
    /// card.
    var canUndoLast: Bool {
        previous != nil && document.undoManager?.canUndo == true
    }

    /// Takes back the last review or suspension, like ⌘Z.
    func undoLast() {
        guard canUndoLast else { return }
        document.undoManager?.undo()
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

    /// Checks responses with the deck's learning options.
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
            stage = .feedback(result, response: input)
        }
    }

    /// Flash cards: shows the answer.
    func reveal() {
        guard studyBy == .flashcards, stage == .asking else { return }
        stage = .revealed
    }

    /// With flash cards only once the answer is shown.
    func grade(_ grade: Grade) {
        guard stage != .finished, studyBy == .typing || stage == .revealed, let card = currentCard, driver.grade(grade) else { return }
        previous = PreviousReview(question: card.question, answer: card.answer, grade: grade)
    }

    /// Suspends the card being asked, so no session asks it until the learner resumes
    /// it in the card list, and moves on (#290). ⌘Z takes it back like a review.
    func suspendCurrentCard() {
        guard stage != .finished, let card = currentCard, driver.suspendCurrentCard() else { return }
        previous = PreviousReview(question: card.question, answer: card.answer, grade: nil)
    }

    /// Only finishes the cards already asked.
    func finishUp() {
        driver.finishUp()
    }

    /// The mistakes of this session that are still in the deck and not suspended.
    var mistakesToPractice: [Card.ID] {
        session.mistakeIDs.filter { document.card(withID: $0)?.isSuspended == false }
    }

    /// Practises the mistakes of this session once more, without
    /// affecting their schedule.
    func practiceMistakes() {
        let ids = mistakesToPractice
        guard !ids.isEmpty else { return }
        previous = nil
        driver.start(.practice(Practice(practicing: ids, at: document.clock.now)))
    }

    /// Starts a new regular session with the cards that are still due.
    func continueStudying() {
        previous = nil
        driver.start(.study(Self.makeStudySession(for: document, studyBy: studyBy)))
    }

    private static func makeStudySession(for document: VocabularyDocument, studyBy: Preferences.StudyBy) -> StudySession {
        StudySession(deck: document.deck, at: document.clock.now, calendar: document.calendar, reviewMode: studyBy == .flashcards ? .revealed : .typed)
    }
}

extension SessionViewModel: SessionDriverDelegate {
    func sessionDriverDidMoveOn(_ driver: SessionDriver) {
        input = ""
        questionNumber += 1
        stage = session.isFinished ? .finished : .asking
    }

    /// Checks the response shown again against the card as it is now, e.g. after
    /// undoing an edit of its answer.
    func sessionDriverCardDidChange(_ driver: SessionDriver) {
        if case let .feedback(_, response) = stage, let card = currentCard {
            stage = .feedback(checker.check(response, against: card.answer), response: response)
        }
    }

    func sessionDriverDidRestore(_ driver: SessionDriver) {
        previous = nil
    }
}
