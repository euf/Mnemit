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
    /// The question that came with the last move came back by Undo: its answer shows, as it did when the
    /// card was graded, and nothing is spoken. The view brings the card back by the way it went.
    private(set) var returnedByUndo = false
    /// Where each undoable step sent its card, one entry per step: what Undo plays backwards.
    private var destinations: [GradeReceipt.Destination] = []
    private var undoIsComing = false

    /// Uses the document's clock, so reviews and the snapshot they update fall on the
    /// same study day. With `rounds`, the plan rests at the end of each round of the day but the
    /// last, see `SessionDriver`; a practice has none. With a `ring`, the rounds come from its progress,
    /// the one it has now and the ones it evaluates while the stream is open (`adoptRounds(_:)`).
    init(document: VocabularyDocument, entry: Entry = .study, rounds: RoundGuide? = nil, ring: DailyRingModel? = nil) {
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
        let guide = rounds ?? ring.flatMap { RoundGuide(progress: $0.progress, document: document) }
        driver = SessionDriver(document: document, stream: stream, rounds: entry == .study ? guide : nil)
        stage = driver.isResting ? .resting : .asking
        driver.delegate = self
        if entry == .study, let ring { follow(ring) }
    }

    /// Takes the rounds of the day from the progress of `ring` each time it changes while the stream is open.
    private func follow(_ ring: DailyRingModel) {
        withObservationTracking {
            _ = ring.progress
        } onChange: { [weak self, weak ring] in
            // Called before the change: the new progress is there on the next turn.
            Task { @MainActor in
                guard let self, let ring else { return }
                self.adoptRounds(RoundGuide(progress: ring.progress, document: self.document))
                self.follow(ring)
            }
        }
    }

    /// The progress of the day was evaluated, or evaluated again: the rounds count from the next card on,
    /// and the stream does not rest for a round the cards done by now have ended.
    func adoptRounds(_ guide: RoundGuide?) {
        driver.adoptRounds(guide)
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

    /// The cards of the current round waiting behind the one being asked, the ones that come back
    /// today included: the view shows them as a stack of edges under the card. 0 without rounds,
    /// in practice and once the goal is met.
    var cardsBehind: Int {
        max(0, (driver.cardsLeftInRound ?? 0) - 1)
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

    /// - Returns: What the grade did, or `nil` if it was not given. Where the receipt sends the
    ///   card (`GradeReceipt.destination`) decides how the view lets it leave.
    @discardableResult
    func grade(_ grade: Grade) -> GradeReceipt? {
        guard stage == .revealed, driver.grade(grade), let receipt = driver.lastReceipt else { return nil }
        destinations.append(receipt.destination)
        return receipt
    }

    /// Suspends the card being asked, so no session asks it until the learner resumes
    /// it on the Mac, and moves on (#290). Undo takes it back like a review.
    func suspendCurrentCard() {
        guard stage != .resting else { return }
        if driver.suspendCurrentCard() { destinations.append(.away) }
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

    /// Whether Undo can take back a review or suspension of this stream: the condition of the
    /// button in the bar and of the one in the menu.
    var canUndo: Bool {
        hasUndoableSteps && document.undoManager?.canUndo == true
    }

    /// How the card that Undo brings back went away, so the view plays it backwards; `nil` where Undo
    /// has nothing to take back. The stream at rest has the card's grade behind it: the ring has gone
    /// down to the rest, and goes back up before the card returns.
    var undoReturn: UndoReturn? {
        guard canUndo, let from = destinations.last else { return nil }
        return UndoReturn(from: from, fromRest: isResting)
    }

    /// Takes back the last review or suspension of this stream, like Undo in the menu.
    func undoLast() {
        guard canUndo else { return }
        document.undoManager?.undo()
    }
}

/// Where the card that Undo brings back comes from, see `StudyModel.undoReturn`.
struct UndoReturn: Equatable {
    /// Where its grade sent the card: the ring, under the stack, or away.
    var from: GradeReceipt.Destination
    /// The stream rests now.
    var fromRest: Bool
}

extension StudyModel: SessionDriverDelegate {
    func sessionDriverDidMoveOn(_ driver: SessionDriver) {
        questionNumber += 1
        returnedByUndo = undoIsComing
        undoIsComing = false
        stage = driver.isResting ? .resting : (returnedByUndo ? .revealed : .asking)
    }

    /// Undo or redo of a step: the steps of the stream are as many as the stream says now. A card
    /// that Undo brings back shows its answer.
    func sessionDriverDidRestore(_ driver: SessionDriver) {
        let steps = driver.stream.stepCount
        destinations.removeLast(max(0, destinations.count - steps))
        while destinations.count < steps { destinations.append(.away) }
        undoIsComing = document.undoManager?.isUndoing == true
    }
}
