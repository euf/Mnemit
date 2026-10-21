import Foundation
import Observation
import VocabCore

/// Drives a study session in the style of flash cards (#258): shows the question,
/// reveals the answer on request and applies the grade the learner gives. There is no
/// response to check, so the app suggests no grade; the reviews record `.revealed`. At the
/// end, the learner can practise the mistakes, which changes no card.
///
/// Like `SessionViewModel` on the Mac, it leaves applying grades and keeping the
/// session's place in step with undo and redo and with every other change to the deck
/// to a `SessionDriver` (#264).
@MainActor @Observable
final class StudyModel: Identifiable {
    enum Stage: Equatable {
        /// The question is shown.
        case asking
        /// The answer is shown too; waiting for a grade.
        case revealed
        case finished
    }

    let document: VocabularyDocument
    private let driver: SessionDriver
    private(set) var stage: Stage
    /// Counts the questions asked: one more with every move to another card, also back
    /// after an undo, and to the end. The view speaks a Greek question when it changes.
    private(set) var questionNumber = 0

    /// Uses the document's clock, so reviews and the snapshot they update fall on the
    /// same study day.
    init(document: VocabularyDocument) {
        self.document = document
        driver = SessionDriver(document: document, mode: Self.makeSession(for: document))
        stage = driver.session.isFinished ? .finished : .asking
        driver.delegate = self
    }

    /// A study session, or practice of its mistakes; `SessionMode` is how the core
    /// records the reviews.
    var mode: SessionMode { driver.mode }

    var session: Session { driver.session }

    /// The card being asked, as the deck holds it now.
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

    func reveal() {
        guard stage == .asking else { return }
        stage = .revealed
    }

    func grade(_ grade: Grade) {
        guard stage == .revealed else { return }
        driver.grade(grade)
    }

    /// Suspends the card being asked, so no session asks it until the learner resumes
    /// it on the Mac, and moves on (#290). Undo takes it back like a review.
    func suspendCurrentCard() {
        guard stage != .finished else { return }
        driver.suspendCurrentCard()
    }

    /// Whether this session did something that undo takes back: a review or a
    /// suspension. Undo beyond them would change cards the session doesn't show.
    var hasUndoableSteps: Bool {
        session.reviewCount > 0 || session.suspendedCount > 0
    }

    /// Takes back the last review or suspension of this session, like Undo in the menu.
    func undoLast() {
        guard hasUndoableSteps, document.undoManager?.canUndo == true else { return }
        document.undoManager?.undo()
    }

    /// The mistakes of this session that are still in the deck and not suspended.
    var mistakesToPractice: [Card.ID] {
        session.mistakeIDs.filter { document.card(withID: $0)?.isSuspended == false }
    }

    /// Practises the mistakes of this session once more, without affecting their
    /// schedule, as on the Mac.
    func practiceMistakes() {
        let ids = mistakesToPractice
        guard !ids.isEmpty else { return }
        driver.start(.practice(Practice(practicing: ids, at: document.clock.now)))
    }

    /// Starts a new study session with the cards that are still due.
    func continueStudying() {
        driver.start(Self.makeSession(for: document))
    }

    private static func makeSession(for document: VocabularyDocument) -> SessionMode {
        .study(StudySession(deck: document.deck, at: document.clock.now, calendar: document.calendar, reviewMode: .revealed))
    }
}

extension StudyModel: SessionDriverDelegate {
    func sessionDriverDidMoveOn(_ driver: SessionDriver) {
        questionNumber += 1
        stage = session.isFinished ? .finished : .asking
    }
}
