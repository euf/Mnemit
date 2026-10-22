import Combine
import Foundation
import Observation
import VocabCore

/// Runs a study stream over the deck of a document, for `SessionViewModel` on the Mac and
/// `StudyModel` on the iPhone (#264): applies grades to the document and keeps the
/// stream's place in step with undo and redo of its reviews and with every other
/// change to the deck, e.g. a merge that deleted the card being asked.
///
/// What a model adds, like checking typed responses or revealing the answer, it does
/// around the driver. The driver tells it through its delegate when it moved on.
@MainActor @Observable
final class SessionDriver {
    let document: VocabularyDocument
    /// The running stream: today's plan, then catch-up, review ahead and practice. Undo and
    /// redo bring back the whole of it, so they reach a review of an earlier segment as well.
    private(set) var stream: StudyStream
    /// The card being asked, as the deck holds it now. Undoing an edit of the card
    /// during the stream shows up here.
    private(set) var currentCard: Card?
    /// What the last grade did, until the learner has seen it, undone it or moved on; see
    /// `UndoChip`. Practice and study alike leave one.
    private(set) var lastReceipt: GradeReceipt?
    @ObservationIgnored weak var delegate: (any SessionDriverDelegate)?
    @ObservationIgnored private var deckObservation: AnyCancellable?
    /// Times the card being asked, from the moment `moveOn()` shows it.
    @ObservationIgnored private var stopwatch: ActiveStopwatch

    /// Starts with the current card of `stream`, or at rest. Tells the delegate of no
    /// move: it isn't set yet. `now` is the monotonic clock that times the cards; a test
    /// moves it.
    init(document: VocabularyDocument, stream: StudyStream, now: @escaping () -> SuspendingClock.Instant = { .now }) {
        self.document = document
        self.stream = stream
        stopwatch = ActiveStopwatch(now: now)
        advance()
        refreshCurrentCard()
        deckObservation = document.deckDidChange.sink { [weak self] in
            self?.deckDidChange()
        }
    }

    /// The segment running; its mode decides how a review is recorded.
    var mode: SessionMode { stream.mode }

    /// The part of the segment that study and practice share.
    var session: Session { stream.session }

    /// The stream waits for the learner: today's plan is done, or the practice of a
    /// practice-only stream.
    var isResting: Bool { stream.isResting }

    /// When the card being asked would be asked next after each grade, if given now; `nil`
    /// in practice, which schedules nothing, and without a card.
    var gradeIntervals: [Grade: ReviewInterval]? {
        guard case let .study(study) = mode, let card = currentCard else { return nil }
        let scheduler = Scheduler(learningOptions: document.deck.learningOptions, calendar: document.calendar)
        return scheduler.previewIntervals(of: card, at: document.clock.now, mode: study.reviewMode)
    }

    /// Grades the card being asked and moves on. One undo action takes back the review
    /// and the stream's place: the document restores the card, then the stream.
    /// Practice changes no card, but undo should still take back the last review
    /// instead of reaching a review before the practice.
    ///
    /// - Returns: Whether the stream recorded the review; it doesn't while it rests, nor
    ///   while the document can't be changed (#305).
    @discardableResult
    func grade(_ grade: Grade) -> Bool {
        guard document.isReadyToEdit else { return false }
        let before = stream
        let interval = gradeIntervals?[grade]
        let duration = stopwatch.elapsed
        guard let outcome = stream.grade(grade, in: document.deck, at: document.clock.now, calendar: document.calendar, duration: duration) else { return false }
        let restore = sessionRestore(from: before, to: stream)
        switch outcome {
        case let .rescheduled(change):
            document.applyReview(change, alongside: restore)
        case .practiced:
            registerPracticeUndo(restore)
        }
        lastReceipt = GradeReceipt(grade: grade, interval: interval, isLeech: stream.session.leechIDs.count > before.session.leechIDs.count)
        moveOn()
        return true
    }

    /// The app became active or stopped being: the time while it isn't active is not on any
    /// card's account (`ReviewLogEntry.duration`). It starts out active; the model reports
    /// the changes: the scene phase on the iPhone, the application on the Mac.
    func setActive(_ isActive: Bool) {
        stopwatch.setActive(isActive)
    }

    /// The learner has seen what the last grade did.
    func dismissReceipt() {
        lastReceipt = nil
    }

    /// Suspends the card being asked and moves on (#290). Like a review, one undo action
    /// takes back the suspension and the stream's place: the document resumes the
    /// card, then the stream asks it again.
    ///
    /// - Returns: Whether the card was suspended; it isn't while the stream rests,
    ///   nor while the document can't be changed (#305).
    @discardableResult
    func suspendCurrentCard() -> Bool {
        guard document.isReadyToEdit, let id = session.currentCardID, let card = document.card(withID: id), !card.isSuspended else { return false }
        let before = stream
        stream.perform(.suspend)
        guard document.setSuspended(true, of: [id], alongside: sessionRestore(from: before, to: stream)) else {
            stream = before
            return false
        }
        lastReceipt = nil
        moveOn()
        return true
    }

    /// From rest, goes on beyond the plan: the catch-up, review ahead, practice.
    func keepGoing() {
        guard stream.keepGoing(in: document.deck, at: document.clock.now, calendar: document.calendar) else { return }
        lastReceipt = nil
        moveOn()
    }

    /// Adds `StudyStream.newCardChunk` new cards beyond the daily limits to the stream,
    /// from rest or in the middle of it.
    func addNewCards() {
        guard stream.addNewCards(StudyStream.newCardChunk, in: document.deck, at: document.clock.now, calendar: document.calendar) else { return }
        lastReceipt = nil
        moveOn()
    }

    /// The new cards `addNewCards()` would add now and what they cost in cards a day next
    /// week; `nil` if there are none, and for a practice.
    var extraNew: ExtraNewCards? {
        guard !stream.isPracticeOnly else { return nil }
        let count = StudyStream.extraNewCards(
            in: document.deck, at: document.clock.now, calendar: document.calendar, newCardAllowance: stream.newCardAllowance)
        guard count > 0 else { return nil }
        let load = NewCardLoad.reviewsPerDay(addingNewCards: count, options: document.deck.learningOptions, at: document.clock.now, calendar: document.calendar)
        return ExtraNewCards(cards: count, reviewsPerDay: Int(load.rounded()))
    }

    /// What the stream shows at rest.
    var rest: StreamRest {
        let counts = StudySession.counts(for: document.deck, at: document.clock.now, calendar: document.calendar, newCardAllowance: stream.newCardAllowance)
        return StreamRest(
            isPracticeOnly: stream.isPracticeOnly,
            recap: stream.recap,
            nextDue: counts.nextDue,
            now: document.clock.now,
            catchUp: counts.catchUp,
            canKeepGoing: stream.canKeepGoing(in: document.deck, at: document.clock.now, calendar: document.calendar),
            extraNew: extraNew)
    }

    /// Moves to the current card, past cards deleted or suspended meanwhile and on to the
    /// next segment of the stream as the one before runs out, and tells the delegate.
    private func moveOn() {
        advance()
        refreshCurrentCard()
        stopwatch.restart()
        delegate?.sessionDriverDidMoveOn(self)
    }

    /// The stream moves on once the segment has no card to ask, which may be several
    /// segments in a row if the cards of one are all gone.
    private func advance() {
        repeat {
            skipUnaskableCards()
        } while stream.advance(in: document.deck, at: document.clock.now, calendar: document.calendar)
    }

    /// Cards deleted meanwhile, e.g. by undoing "Add Card" or by a merge, can't be
    /// asked, nor can cards suspended meanwhile, e.g. on another device.
    private func skipUnaskableCards() {
        while let id = session.currentCardID, !canAsk(id) {
            stream.perform(.skip)
        }
    }

    private func canAsk(_ id: Card.ID) -> Bool {
        guard let card = document.card(withID: id) else { return false }
        return !card.isSuspended
    }

    private func refreshCurrentCard() {
        currentCard = session.currentCardID.flatMap(document.card(withID:))
    }

    /// Runs after every change to the deck, the session's own reviews included. Moves
    /// on if the card being asked is gone or suspended.
    private func deckDidChange() {
        if let id = session.currentCardID, !canAsk(id) {
            moveOn()
        } else {
            refreshCurrentCard()
            delegate?.sessionDriverCardDidChange(self)
        }
    }

    /// Brings back the stream's place before a review on undo and after it on redo.
    /// Holds the driver weakly: the document's undo stack outlives a closed stream.
    private func sessionRestore(from before: StudyStream, to after: StudyStream) -> UndoCompanion {
        UndoCompanion(
            undo: { [weak self] in self?.restore(before) },
            redo: { [weak self] in self?.restore(after) }
        )
    }

    /// Registers `companion` as the undo action of a practice review, which changes no
    /// card: the document only registers it, see `VocabularyDocument.registerUndo(_:actionName:)`.
    ///
    /// It lands on the document's undo manager all the same, so NSDocument counts it as
    /// a change: the deck shows as edited and autosave writes it unchanged. Marking the
    /// action discardable doesn't prevent that. Accepted, because without the undo
    /// action ⌘Z would reach the last review of the earlier study session (#166).
    ///
    /// The target is the document, like for a review in a study session: the driver may
    /// be gone before the undo stack, and the handler reaches it only through `companion`
    /// (#174).
    private func registerPracticeUndo(_ companion: UndoCompanion) {
        document.registerUndo(companion, actionName: String(localized: "Review"))
    }

    /// Called by undo and redo of a review. The snapshot is the stream as it was, whatever
    /// segment it was in: undoing the last review of the plan after review ahead began
    /// asks that card again, and redo moves on again.
    private func restore(_ snapshot: StudyStream) {
        guard snapshot.id == stream.id else { return }  // a different stream by now
        stream = snapshot
        lastReceipt = nil
        delegate?.sessionDriverDidRestore(self)
        moveOn()
    }
}

/// What a model around a `SessionDriver` hears of. Each call comes after the driver's
/// `stream` and `currentCard` hold the new state.
@MainActor
protocol SessionDriverDelegate: AnyObject {
    /// The driver moved on to the next card, or to rest: after a grade, going on beyond
    /// the plan, new cards, undo or redo, or because the card being asked was deleted.
    func sessionDriverDidMoveOn(_ driver: SessionDriver)
    /// The deck changed, but the card being asked is still there; `currentCard` holds
    /// it as the deck does now.
    func sessionDriverCardDidChange(_ driver: SessionDriver)
    /// Undo or redo brought back the stream's place before or after a review; the
    /// driver moves on right after.
    func sessionDriverDidRestore(_ driver: SessionDriver)
}

extension SessionDriverDelegate {
    func sessionDriverCardDidChange(_ driver: SessionDriver) {}
    func sessionDriverDidRestore(_ driver: SessionDriver) {}
}

/// How long the card being asked has been on screen with the app active; see `ReviewLogEntry.duration`.
///
/// It counts from the moment a card is shown (`restart()`) and stands still while the app is
/// not active (`setActive(_:)`): in the background, with the phone locked, behind another app.
/// A suspending clock, so a Mac asleep with a card on screen doesn't count either. No cap: a
/// card left open in an active app counts, and the pace takes a robust estimate of them.
struct ActiveStopwatch {
    private let now: () -> SuspendingClock.Instant
    private var banked: Duration = .zero
    /// When the running stretch began; `nil` while the app is inactive.
    private var since: SuspendingClock.Instant?
    private(set) var isActive = true

    /// Running from now, with the app active.
    init(now: @escaping () -> SuspendingClock.Instant = { .now }) {
        self.now = now
        since = now()
    }

    /// A new card is on screen: counts from zero.
    mutating func restart() {
        banked = .zero
        since = isActive ? now() : nil
    }

    mutating func setActive(_ active: Bool) {
        guard active != isActive else { return }
        if !active { banked = elapsed }
        isActive = active
        since = active ? now() : nil
    }

    var elapsed: Duration {
        banked + (since.map { now() - $0 } ?? .zero)
    }
}
