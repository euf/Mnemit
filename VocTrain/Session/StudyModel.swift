import Foundation
import Observation
import VocabCore

/// Drives the study stream in the style of flash cards (#258): shows the question,
/// reveals the answer on request and applies the grade the learner gives. There is no
/// response to check, so the app suggests no grade; the reviews record `.revealed`. The
/// stream has no end of its own: today's plan, a short rest, then catch-up, review ahead and
/// practice, which changes no card.
///
/// Like `SessionViewModel` on the Mac, it leaves applying grades and keeping the
/// stream's place in step with undo and redo and with every other change to the deck
/// to a `SessionDriver` (#264).
@MainActor @Observable
final class StudyModel: Identifiable {
    enum Stage: Equatable {
        /// The question is shown.
        case asking
        /// The answer is shown too; waiting for a grade.
        case revealed
        /// The stream waits for the learner, see `StudyStream.Stage.rest`.
        case resting
    }

    /// What the stream starts with.
    enum Entry {
        /// Today's plan, then catch-up, review ahead and practice.
        case study
        /// A practice of the cards that went wrong today, which changes no card.
        case practiceMistakes
        /// A practice of the newest words, which changes no card.
        case practiceNewest
    }

    let document: VocabularyDocument
    private let driver: SessionDriver
    private(set) var stage: Stage
    /// Counts the questions asked: one more with every move to another card, also back
    /// after an undo, and to rest. The view speaks a Greek question when it changes.
    private(set) var questionNumber = 0
    /// Counts the reviews that sent a card to another day, which is a card done: the view pulses
    /// its background when it grows, once per review, however the grade was given. Undo and redo
    /// don't count.
    private(set) var progressPulses = 0

    /// Uses the document's clock, so reviews and the snapshot they update fall on the
    /// same study day. With `rounds`, the plan rests at the end of each round of the day but the
    /// last, see `SessionDriver`; a practice has none.
    init(document: VocabularyDocument, entry: Entry = .study, rounds: RoundGuide? = nil) {
        // Before the first card shows: the voice and the audio session are ready by then, and
        // the stream's speech never sets them up in the middle of an animation. Before the
        // driver too: its stopwatch starts with the first card, and opening the voice isn't on
        // the card's account.
        GreekSpeech.shared.open()
        let now = document.clock.now
        let stream: StudyStream
        switch entry {
        case .study:
            stream = StudyStream(
                deck: document.deck, at: now, calendar: document.calendar, reviewMode: .revealed, newCardAllowance: document.newCardAllowance)
        case .practiceMistakes:
            stream = StudyStream(practicingMistakesIn: document.deck, at: now, calendar: document.calendar)
        case .practiceNewest:
            stream = StudyStream(practicingNewestWordsIn: document.deck, at: now)
        }
        self.document = document
        driver = SessionDriver(document: document, stream: stream, rounds: entry == .study ? rounds : nil)
        stage = driver.isResting ? .resting : .asking
        driver.delegate = self
    }

    /// The segment running: study, or practice; `SessionMode` is how the core records the
    /// reviews.
    var mode: SessionMode { driver.mode }

    var session: Session { driver.session }

    /// Where the stream is: today's plan, catch-up, review ahead, practice, or at rest.
    var streamStage: StudyStream.Stage { driver.stream.stage }

    /// The card being asked, as the deck holds it now.
    var currentCard: Card? { driver.currentCard }

    var isPracticing: Bool { streamStage.isPractice }

    var isResting: Bool { stage == .resting }

    /// What the stream shows at rest.
    var rest: StreamRest { driver.rest }

    /// What the last grade did, shown in the chip that offers Undo.
    var receipt: GradeReceipt? { driver.lastReceipt }

    func dismissReceipt() {
        driver.dismissReceipt()
    }

    /// Whether the app is active (the scene phase): the time while it isn't is left out of
    /// the duration a review logs.
    func setActive(_ isActive: Bool) {
        driver.setActive(isActive)
    }

    func reveal() {
        guard stage == .asking else { return }
        stage = .revealed
    }

    func grade(_ grade: Grade) {
        guard stage == .revealed, driver.grade(grade) else { return }
        // FSRS let the card go to another day: progress the learner can feel. Not a card that
        // comes back today, a practice (no interval) or a leech that was suspended.
        if let receipt = driver.lastReceipt, !receipt.isLeech, case .days = receipt.interval {
            progressPulses += 1
        }
    }

    /// Suspends the card being asked, so no session asks it until the learner resumes
    /// it on the Mac, and moves on (#290). Undo takes it back like a review.
    func suspendCurrentCard() {
        guard stage != .resting else { return }
        driver.suspendCurrentCard()
    }

    /// Whether the rest is the end of a round, not of the plan: Next Round goes on with the plan.
    var isRoundRest: Bool { isResting && rest.roundEnd != nil }

    /// Goes on with the next round, from the rest at the end of one.
    func continueRound() {
        driver.continueRound()
    }

    /// Goes on beyond the plan, from rest: catch-up, review ahead, then practice.
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

    /// Whether the stream did something that undo takes back: a review or a suspension,
    /// in any segment. Undo beyond them would change cards the stream doesn't show.
    var hasUndoableSteps: Bool {
        driver.stream.stepCount > 0
    }

    /// Takes back the last review or suspension of this stream, like Undo in the menu.
    func undoLast() {
        guard hasUndoableSteps, document.undoManager?.canUndo == true else { return }
        document.undoManager?.undo()
    }
}

extension StudyModel: SessionDriverDelegate {
    func sessionDriverDidMoveOn(_ driver: SessionDriver) {
        questionNumber += 1
        stage = driver.isResting ? .resting : .asking
    }
}
