import AppKit
import Combine
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
        /// Today's stack: the plan, which ends; past it only Push On.
        case study
        /// Today's stack once it is done: Push On, ten new cards at once, without the rest at the end of the plan
        /// first.
        case pushOn
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
    /// Tells the driver when the application stops being active: the time away is not on a card.
    @ObservationIgnored private var activityObservation: AnyCancellable?
    private(set) var stage: Stage
    private(set) var previous: PreviousReview?
    /// Counts the questions asked. The view gives each question a response field of
    /// its own, so ⌘Z can't reach the typing for an earlier one (#9).
    private(set) var questionNumber = 0
    var input = ""

    /// Uses the document's clock, so reviews and the snapshot they update fall on the same study day.
    /// Types by default, so a test doesn't depend on the learner's preference; the app passes it.
    ///
    /// With `rounds`, the plan rests at the end of each round of the day but the last, see `SessionDriver`;
    /// a practice has none.
    init(
        document: VocabularyDocument, autoAdvance: Bool = Preferences.autoAdvance, studyBy: Preferences.StudyBy = .typing, entry: Entry = .study,
        rounds: RoundGuide? = nil
    ) {
        let now = document.clock.now
        let stream: StudyStream
        switch entry {
        case .study, .pushOn:
            stream = StudyStream(
                deck: document.deck, at: now, calendar: document.calendar, reviewMode: studyBy == .flashcards ? .revealed : .typed,
                newCardAllowance: document.newCardAllowance)
        case .practiceMistakes:
            stream = StudyStream(practicingMistakesIn: document.deck, at: now, calendar: document.calendar)
        case .practiceNewest:
            stream = StudyStream(practicingNewestWordsIn: document.deck, at: now)
        }
        self.document = document
        self.autoAdvance = autoAdvance
        self.studyBy = studyBy
        driver = SessionDriver(document: document, stream: stream, rounds: entry == .practiceMistakes || entry == .practiceNewest ? nil : rounds)
        if entry == .pushOn {
            driver.addNewCards()
        }
        stage = driver.isResting ? .resting : .asking
        driver.delegate = self
        let center = NotificationCenter.default
        activityObservation = center.publisher(for: NSApplication.didBecomeActiveNotification).map { _ in true }
            .merge(with: center.publisher(for: NSApplication.didResignActiveNotification).map { _ in false })
            .sink { [weak self] in self?.driver.setActive($0) }
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

    /// Goes on with the next round, from the rest at the end of one.
    func continueRound() {
        driver.continueRound()
    }

    /// Push On: adds 10 new cards beyond the daily limits to the stack that is done for the day.
    func addNewCards() {
        driver.addNewCards()
    }

    /// The cards of the current round waiting behind the one asked, as the iPhone's stack shows them; 0 without
    /// rounds, in practice and once the goal is met.
    var cardsBehind: Int { max(0, (driver.cardsLeftInRound ?? 0) - 1) }

    /// The new cards `addNewCards()` would add; `nil` if there are none and for a practice.
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
