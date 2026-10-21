import Foundation
import Observation
import VocabCore

/// Drives the study stream on the Mac: checks responses and moves on after a correct one
/// if asked to. With flash cards (`studyBy`) there is no response to check: the learner
/// reveals the answer and grades it. Applying grades and keeping the stream's place in
/// step with undo and redo and with every other change to the deck is left to a
/// `SessionDriver`, which the iPhone app shares.
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

    /// What the stream starts with.
    enum Entry {
        /// Today's plan, then review ahead and practice.
        case study
        /// A practice of the cards that went wrong today, which changes no card.
        case practiceMistakes
        /// A practice of the newest words, which changes no card.
        case practiceNewest
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
    /// How the stream asks its cards.
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
    ///
    init(document: VocabularyDocument, autoAdvance: Bool = Preferences.autoAdvance, studyBy: Preferences.StudyBy = .typing, entry: Entry = .study) {
        let now = document.clock.now
        let stream: StudyStream
        switch entry {
        case .study:
            stream = StudyStream(deck: document.deck, at: now, calendar: document.calendar, reviewMode: studyBy == .flashcards ? .revealed : .typed)
        case .practiceMistakes:
            stream = StudyStream(practicingMistakesIn: document.deck, at: now, calendar: document.calendar)
        case .practiceNewest:
            stream = StudyStream(practicingNewestWordsIn: document.deck, at: now)
        }
        self.document = document
        self.autoAdvance = autoAdvance
        self.studyBy = studyBy
        driver = SessionDriver(document: document, stream: stream)
        stage = driver.isResting ? .resting : .asking
        driver.delegate = self
    }

    /// The segment running; its mode decides how a review is recorded.
    var mode: SessionMode { driver.mode }

    /// The part of the segment that study and practice share.
    var session: Session { driver.session }

    /// Where the stream is: today's plan, review ahead, practice, or at rest.
    var streamStage: StudyStream.Stage { driver.stream.stage }

    /// The card being asked, as the deck holds it now. Undoing an edit of the card
    /// during the session shows up here.
    var currentCard: Card? { driver.currentCard }

    var isPracticing: Bool { streamStage.isPractice }

    var isResting: Bool { stage == .resting }

    /// What the stream shows at rest.
    var rest: StreamRest { driver.rest }

    /// Goes on beyond the plan, from rest: review ahead, then practice.
    func keepGoing() {
        driver.keepGoing()
    }

    /// Adds 10 new cards beyond the daily limits, from rest or in the middle of the stream.
    func addNewCards() {
        driver.addNewCards()
    }

    /// The new cards `addNewCards()` would add and what they cost; `nil` if there are none
    /// and for a practice.
    var extraNew: ExtraNewCards? { driver.extraNew }

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
        guard stage != .resting, studyBy == .typing || stage == .revealed, let card = currentCard, driver.grade(grade) else { return }
        previous = PreviousReview(question: card.question, answer: card.answer, grade: grade)
    }

    /// Suspends the card being asked, so no session asks it until the learner resumes
    /// it in the card list, and moves on (#290). ⌘Z takes it back like a review.
    func suspendCurrentCard() {
        guard stage != .resting, let card = currentCard, driver.suspendCurrentCard() else { return }
        previous = PreviousReview(question: card.question, answer: card.answer, grade: nil)
    }
}

extension SessionViewModel: SessionDriverDelegate {
    func sessionDriverDidMoveOn(_ driver: SessionDriver) {
        input = ""
        questionNumber += 1
        stage = driver.isResting ? .resting : .asking
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
