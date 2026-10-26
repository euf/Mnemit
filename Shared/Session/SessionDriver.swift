import Combine
import Foundation
import Observation
import VocabCore

/// Runs a study stream over the deck of a document, for `SessionViewModel` on the Mac and
/// `StudyModel` on the iPhone (#264): applies grades to the document and keeps the
/// stream's place in step with undo and redo of its reviews and with every other
/// change to the deck, e.g. a merge that deleted the card being asked.
///
/// What a model adds, like revealing the answer, it does around the driver. The driver
/// tells it through its delegate when it moved on.
@MainActor @Observable
final class SessionDriver {
    let document: VocabularyDocument
    /// The running stream: today's plan, then what Push On adds, or one practice. Undo and
    /// redo bring back the whole of it, so they reach a review of an earlier segment as well.
    private(set) var stream: StudyStream
    /// The card being asked, as the deck holds it now. Undoing an edit of the card
    /// during the stream shows up here.
    private(set) var currentCard: Card?
    /// What the last grade did, until the learner has seen it, undone it or moved on; see
    /// `UndoChip`. Practice and study alike leave one.
    private(set) var lastReceipt: GradeReceipt?
    /// How many cards the round of the day the stream is in still holds, the card being asked and the
    /// ones that come back today included; `nil` without a guide to the rounds, and once the goal is met.
    private(set) var cardsLeftInRound: Int?
    @ObservationIgnored weak var delegate: (any SessionDriverDelegate)?
    @ObservationIgnored private var deckObservation: AnyCancellable?
    /// Times the card being asked, from the moment `moveOn()` shows it.
    @ObservationIgnored private var stopwatch: ActiveStopwatch
    /// Where the rounds of the day end, so the stream rests at each; `nil` for a stream that doesn't:
    /// practice, and a day whose rounds are not known, which `adoptRounds(_:)` may yet bring.
    private(set) var rounds: RoundGuide?

    /// Starts with the current card of `stream`, or at rest. Tells the delegate of no
    /// move: it isn't set yet. `now` is the monotonic clock that times the cards; a test
    /// moves it. With `rounds` the stream rests at the end of each round of the day but the last:
    /// the rounds that are done by then are not rested for.
    init(document: VocabularyDocument, stream: StudyStream, rounds: RoundGuide? = nil, now: @escaping () -> SuspendingClock.Instant = { .now }) {
        self.document = document
        self.stream = stream
        self.rounds = rounds
        stopwatch = ActiveStopwatch(now: now)
        if let rounds { self.stream.startRounds(at: rounds.roundsDone(cardsDone: rounds.cardsDone(in: document))) }
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
    /// practice-only stream, or the plan stops at the end of a round.
    var isResting: Bool { stream.isResting }

    /// When the card being asked would be asked next after each grade, if given now; `nil`
    /// in practice, which schedules nothing, and without a card.
    var gradeIntervals: [Grade: ReviewInterval]? {
        guard case .study = mode, let card = currentCard else { return nil }
        let scheduler = Scheduler(learningOptions: document.deck.learningOptions, calendar: document.calendar)
        return scheduler.previewIntervals(of: card, at: document.clock.now)
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
        let graded = session.currentCardID
        let creditBefore = graded.map(credit(of:)) ?? 0
        let stepBefore = graded.flatMap { document.card(withID: $0) }.map(MaturityCategory.init(card:))
        let wasNew = graded.flatMap { document.card(withID: $0) }?.isNew ?? false
        let interval = gradeIntervals?[grade]
        let duration = stopwatch.elapsed
        guard let outcome = StallTrace.measure("stream.grade", { stream.grade(grade, in: document.deck, at: document.clock.now, calendar: document.calendar, duration: duration) }) else { return false }
        let restore = sessionRestore(from: before, to: stream)
        switch outcome {
        case let .rescheduled(change):
            StallTrace.measure("applyReview") { document.applyReview(change, alongside: restore) }
        case .practiced:
            registerPracticeUndo(restore)
        }
        lastReceipt = GradeReceipt(
            grade: grade, interval: interval, isLeech: stream.session.leechIDs.count > before.session.leechIDs.count, isNew: wasNew,
            gain: max(0, (graded.map(credit(of:)) ?? 0) - creditBefore), climb: climb(of: graded, from: stepBefore))
        moveOn()
        return true
    }

    /// The step the card with `id` stands on now, if it is Young or higher and higher than `before`.
    private func climb(of id: Card.ID?, from before: MaturityCategory?) -> MaturityCategory? {
        guard let id, let before, let card = document.card(withID: id) else { return nil }
        let now = MaturityCategory(card: card)
        return now > before && now >= .young ? now : nil
    }

    /// How far today's reviews brought the card with `id` toward done, for the ring.
    private func credit(of id: Card.ID) -> Double {
        document.card(withID: id)?.credit(onDayOf: document.clock.now, calendar: document.calendar, steps: document.deck.learningOptions.steps) ?? 0
    }

    /// Takes the rounds of the day from a progress that arrived, or changed, while the stream is open: the
    /// ring is evaluated after the stream was, say. It counts from the next card on: the rounds the cards
    /// done by now have ended are passed, and the stream does not rest for them, nor turn back to one.
    /// Rounds that end where the ones it has end are the same rounds: the figures of the ring lag a card
    /// or two behind the stream, so they would only move the count of the cards done elsewhere.
    func adoptRounds(_ guide: RoundGuide?) {
        guard let guide, guide.ends != rounds?.ends else { return }
        rounds = guide
        let done = guide.cardsDone(in: document)
        stream.startRounds(at: max(stream.roundsPassed, guide.roundsDone(cardsDone: done)))
        cardsLeftInRound = guide.cardsLeft(cardsDone: done)
    }

    /// The cards done today in the other decks of a run changed: the rounds count them from now on, and
    /// a round they have ended is not rested for again here.
    func setDoneElsewhere(_ count: Int) {
        guard var guide = rounds, guide.doneElsewhere != count else { return }
        guide.doneElsewhere = max(0, count)
        rounds = guide
        let done = guide.cardsDone(in: document)
        stream.startRounds(at: max(stream.roundsPassed, guide.roundsDone(cardsDone: done)))
        cardsLeftInRound = guide.cardsLeft(cardsDone: done)
    }

    /// The app became active or stopped being: the time while it isn't active is not on any
    /// card's account (`ReviewLogEntry.duration`). It starts out active; the model reports
    /// the changes: the scene phase on the iPhone, the application on the Mac.
    func setActive(_ isActive: Bool) {
        stopwatch.setActive(isActive)
    }

    /// The learner has seen what the last grade did.
    func dismissReceipt() {
        StallTrace.mark("dismissReceipt")
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
        guard document.isReadyToEdit, !isResting, let id = session.currentCardID, let card = document.card(withID: id), !card.isSuspended else { return false }
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

    /// From the rest at the end of a round, goes on with the next one.
    func continueRound() {
        guard stream.roundRest != nil else { return }
        stream.continueRound()
        lastReceipt = nil
        moveOn()
    }

    /// Push On: adds `count` new cards beyond the daily limits to the stack that is done for the day.
    func addNewCards(_ count: Int = StudyStream.newCardChunk) {
        guard stream.addNewCards(count, in: document.deck, at: document.clock.now, calendar: document.calendar) else { return }
        lastReceipt = nil
        moveOn()
    }

    /// Study These Now: puts the cards just added (`ids`) first in the stream, ahead of the plan.
    func addCards(_ ids: [Card.ID]) {
        guard stream.addCards(ids, in: document.deck, at: document.clock.now, calendar: document.calendar) else { return }
        lastReceipt = nil
        moveOn()
    }

    /// The new cards `addNewCards()` would add now; `nil` if there are none, and for a practice.
    var extraNew: ExtraNewCards? {
        guard !stream.isPracticeOnly else { return nil }
        let count = StudyStream.extraNewCards(
            in: document.deck, at: document.clock.now, calendar: document.calendar, newCardAllowance: stream.newCardAllowance)
        return count > 0 ? ExtraNewCards(cards: count) : nil
    }

    /// What the stream shows at rest.
    var rest: StreamRest {
        let counts = StudySession.counts(for: document.deck, at: document.clock.now, calendar: document.calendar, newCardAllowance: stream.newCardAllowance)
        return StreamRest(
            isPracticeOnly: stream.isPracticeOnly,
            recap: stream.recap,
            nextDue: counts.nextDue,
            now: document.clock.now,
            extraNew: extraNew,
            roundEnd: stream.roundRest.map { RoundEnd(round: $0, rounds: rounds?.rounds ?? $0 + 1) },
            ringIsBehind: rounds.map { stream.roundsPassed >= $0.rounds } ?? false)
    }

    /// Moves to the current card, past cards deleted or suspended meanwhile and on to the
    /// next segment of the stream as the one before runs out, and tells the delegate.
    private func moveOn() {
        StallTrace.measure("advance") { advance() }
        refreshCurrentCard()
        stopwatch.restart()
        StallTrace.measure("didMoveOn") { delegate?.sessionDriverDidMoveOn(self) }
    }

    /// The stream moves on once the segment has no card to ask, which may be several
    /// segments in a row if the cards of one are all gone.
    private func advance() {
        repeat {
            skipUnaskableCards()
        } while stream.advance(in: document.deck, at: document.clock.now, calendar: document.calendar)
        restAtRoundEnd()
    }

    /// Rests if the cards done, in this deck as it is and in the others as they were, have ended a round
    /// the learner has not been through. Asked every time the stream moves on, so redo finds the rest
    /// again and undo, which brings back a stream from before it, finds none.
    private func restAtRoundEnd() {
        guard let rounds else {
            cardsLeftInRound = nil
            return
        }
        StallTrace.measure("roundGuide") {
            let done = rounds.cardsDone(in: document)
            stream.restAtRoundEnd(roundsDone: rounds.roundsDone(cardsDone: done), rounds: rounds.rounds)
            cardsLeftInRound = rounds.cardsLeft(cardsDone: done)
        }
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

    /// No card while the stream rests at the end of a round: the segment keeps it for the next one.
    private func refreshCurrentCard() {
        currentCard = isResting ? nil : session.currentCardID.flatMap(document.card(withID:))
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

/// Where the rounds of today end, for a stream to rest at: `DailyProgress.roundEnds`, and how many cards
/// the other decks have done, since the rounds count the cards of all decks together. The cards done in
/// the deck the stream runs on are read from the document as it is, after each review.
struct RoundGuide: Equatable, Sendable {
    /// The card counts at which the rounds end, the last the goal.
    var ends: [Int]
    /// The cards done in the decks other than the one the stream runs on.
    var doneElsewhere: Int

    init(ends: [Int], doneElsewhere: Int = 0) {
        self.ends = ends
        self.doneElsewhere = max(0, doneElsewhere)
    }

    /// The guide for a stream over `document`, from the progress the app showed when the stream was
    /// opened; `nil` before there is one, for a day without rounds, and for a paused deck: it is no
    /// part of the day's rounds, so its stream has none to rest at.
    @MainActor
    init?(progress: DailyProgress?, document: VocabularyDocument) {
        guard let progress, progress.rounds > 0, !document.deck.learningOptions.isPaused else { return nil }
        let here = document.deck.doneCards(onDayOf: document.clock.now, calendar: document.calendar)
        self.init(ends: progress.roundEnds, doneElsewhere: progress.ring.done - here)
    }

    var rounds: Int { ends.count }

    /// How many rounds `cardsDone` cards have ended.
    func roundsDone(cardsDone: Int) -> Int { ends.filter { $0 <= cardsDone }.count }

    /// How many cards the round that `cardsDone` cards have reached still asks; `nil` once the last
    /// round, the goal, is done.
    func cardsLeft(cardsDone: Int) -> Int? {
        ends.first { $0 > cardsDone }.map { $0 - cardsDone }
    }

    /// The cards done today across the decks, with `document` as it is.
    @MainActor
    func cardsDone(in document: VocabularyDocument) -> Int {
        doneElsewhere + document.deck.doneCards(onDayOf: document.clock.now, calendar: document.calendar)
    }
}
