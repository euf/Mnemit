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
///
/// Study runs over every active deck at once: one driver per deck (a lane), and each card is taken
/// from the lane whose next card is most urgent: a card in learning that is due, then the review
/// with the lowest recall probability, then a new card from the lane that has given the fewest so
/// far. The grade goes to that card's deck. The rounds of the day count the cards done in all of
/// them; Undo takes back the last step whichever deck it was in.
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

    /// One deck of the run and the driver of its stream.
    private struct Lane {
        let document: VocabularyDocument
        let driver: SessionDriver
        /// New cards this lane has asked in the run, for taking new cards from the decks in turn.
        var newAsked = 0
    }

    private var lanes: [Lane]
    /// The lane whose card is asked now.
    private var current = 0
    /// The deck of the card being asked: the one a grade goes to, and Card Info shows.
    var document: VocabularyDocument { lanes[current].document }
    private var driver: SessionDriver { lanes[current].driver }
    /// The cards done today in the decks that are not in the run, from the ring.
    private var doneInOtherDecks = 0
    /// The lane of each undoable step, in order, for Undo across decks.
    private var stepLanes: [Int] = []
    private var isAppActive = true
    private(set) var stage: Stage
    /// Counts the questions asked: one more with every move to another card, also back
    /// after an undo, and to rest. The view speaks a Greek question when it changes.
    private(set) var questionNumber = 0
    /// The question that came with the last move came back by Undo: its answer shows, as it did when the
    /// card was graded, and nothing is spoken. The view brings the card back by the way it went.
    private(set) var returnedByUndo = false
    /// Where each undoable step sent its card, one entry per step: what Undo plays backwards.
    private var destinations: [GradeReceipt.Destination] = []
    /// The receipt of each step, in step with `destinations`; `nil` for a step that gave no grade.
    private var receipts: [GradeReceipt?] = []
    private var undoIsComing = false

    /// Uses the document's clock, so reviews and the snapshot they update fall on the
    /// same study day. With `rounds`, the plan rests at the end of each round of the day but the
    /// last, see `SessionDriver`; a practice has none. With a `ring`, the rounds come from its progress,
    /// the one it has now and the ones it evaluates while the stream is open (`adoptRounds(_:)`).
    convenience init(document: VocabularyDocument, entry: Entry = .study, rounds: RoundGuide? = nil, ring: DailyRingModel? = nil) {
        self.init(documents: [document], entry: entry, rounds: rounds, ring: ring)
    }

    /// A stream over `documents`, the decks of the run; a practice takes the first only. With `rounds`
    /// (tests), the first deck's guide is that one; otherwise the rounds come from `ring`.
    init(documents: [VocabularyDocument], entry: Entry = .study, rounds: RoundGuide? = nil, ring: DailyRingModel? = nil) {
        precondition(!documents.isEmpty, "a stream needs a deck")
        // Before the first card shows: the voice and the audio session are ready by then, and
        // the stream's speech never sets them up in the middle of an animation. Before the
        // driver too: its stopwatch starts with the first card, and opening the voice isn't on
        // the card's account.
        GreekSpeech.shared.open()
        let decks = entry == .study ? documents : [documents[0]]
        let progress = ring?.progress
        let doneHere = decks.map { $0.deck.doneCards(onDayOf: $0.clock.now, calendar: $0.calendar) }
        // A guide given outright (a test, say) already counts the cards done elsewhere.
        let doneInOthers = rounds?.doneElsewhere ?? max(0, (progress?.ring.done ?? 0) - doneHere.reduce(0, +))
        lanes = decks.enumerated().map { index, document in
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
            var guide: RoundGuide?
            if index == 0, let rounds {
                guide = rounds
            } else if let progress, !progress.roundEnds.isEmpty, !document.deck.learningOptions.isPaused {
                let elsewhere = doneInOthers + doneHere.enumerated().filter { $0.offset != index }.map(\.element).reduce(0, +)
                guide = RoundGuide(ends: progress.roundEnds, doneElsewhere: elsewhere)
            }
            return Lane(document: document, driver: SessionDriver(document: document, stream: stream, rounds: entry == .study ? guide : nil))
        }
        doneInOtherDecks = doneInOthers
        stage = .asking
        for lane in lanes { lane.driver.delegate = self }
        current = mostUrgentLane() ?? 0
        stage = driver.isResting ? .resting : .asking
        activateCurrentLane()
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
                self.adoptRing(ring.progress)
                self.follow(ring)
            }
        }
    }

    /// The progress of the day was evaluated, or evaluated again: the rounds count from the next card on,
    /// and the stream does not rest for a round the cards done by now have ended.
    func adoptRounds(_ guide: RoundGuide?) {
        driver.adoptRounds(guide)
    }

    /// The ring's progress, for every lane: the cards done in the decks outside the run, and the rounds.
    private func adoptRing(_ progress: DailyProgress?) {
        guard let progress else { return }
        let done = lanes.map { $0.document.deck.doneCards(onDayOf: $0.document.clock.now, calendar: $0.document.calendar) }
        doneInOtherDecks = max(0, progress.ring.done - done.reduce(0, +))
        for (index, lane) in lanes.enumerated() where !lane.document.deck.learningOptions.isPaused && !progress.roundEnds.isEmpty {
            let elsewhere = doneInOtherDecks + done.enumerated().filter { $0.offset != index }.map(\.element).reduce(0, +)
            lane.driver.adoptRounds(RoundGuide(ends: progress.roundEnds, doneElsewhere: elsewhere))
        }
        syncRounds()
    }

    /// Hands the lane asked now the cards done in the other lanes, so a round ends where the day's does.
    private func syncRounds() {
        let done = lanes.map { $0.document.deck.doneCards(onDayOf: $0.document.clock.now, calendar: $0.document.calendar) }
        let others = done.enumerated().filter { $0.offset != current }.map(\.element).reduce(0, +)
        driver.setDoneElsewhere(doneInOtherDecks + others)
    }

    /// The lane whose next card is most urgent, among those still in today's plan; `nil` when every lane
    /// has done its plan (or rests).
    private func mostUrgentLane() -> Int? {
        func rank(_ index: Int) -> (Int, Double)? {
            let lane = lanes[index]
            guard !lane.driver.isResting, lane.driver.stream.stage == .plan, let card = lane.driver.currentCard else { return nil }
            let document = lane.document
            guard let state = card.learningState else { return (2, Double(lane.newAsked)) }
            switch state.phase {
            case .learning, .relearning:
                return (0, state.due.timeIntervalSinceReferenceDate)
            case .review:
                return (1, document.deck.recallProbability(of: card, at: document.clock.now, calendar: document.calendar) ?? 1)
            }
        }
        return lanes.indices.compactMap { index in rank(index).map { (index, $0) } }
            .min { $0.1 < $1.1 }?.0
    }

    /// Only the lane asked now runs its stopwatch: the time a card waits in another deck is not its own.
    private func activateCurrentLane() {
        for (index, lane) in lanes.enumerated() {
            lane.driver.setActive(isAppActive && index == current)
        }
        syncRounds()
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
        isAppActive = isActive
        activateCurrentLane()
    }

    func reveal() {
        guard stage == .asking else { return }
        stage = .revealed
    }

    /// - Returns: What the grade did, or `nil` if it was not given. Where the receipt sends the
    ///   card (`GradeReceipt.destination`) decides how the view lets it leave.
    @discardableResult
    func grade(_ grade: Grade) -> GradeReceipt? {
        // The lane is taken first: the grade moves the stream on, and that may turn to another deck.
        let lane = current
        let graded = lanes[lane].driver
        // Counted before the grade: the grade's move on chooses the next deck by it.
        let wasNew = stage == .revealed && currentCard?.isNew == true
        if wasNew { lanes[lane].newAsked += 1 }
        guard stage == .revealed, graded.grade(grade), let receipt = graded.lastReceipt else {
            if wasNew { lanes[lane].newAsked -= 1 }
            return nil
        }
        destinations.append(receipt.destination)
        receipts.append(receipt)
        stepLanes.append(lane)
        return receipt
    }

    /// Suspends the card being asked, so no session asks it until the learner resumes
    /// it on the Mac, and moves on (#290). Undo takes it back like a review.
    func suspendCurrentCard() {
        guard stage != .resting else { return }
        let lane = current
        if driver.suspendCurrentCard() {
            destinations.append(.away)
            receipts.append(nil)
            stepLanes.append(lane)
        }
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
        lanes.contains { $0.driver.stream.stepCount > 0 }
    }

    /// Whether Undo can take back a review or suspension of this stream: the condition of the
    /// button in the bar and of the one in the menu.
    var canUndo: Bool {
        guard let lane = stepLanes.last, lanes[lane].driver.stream.stepCount > 0 else { return false }
        return lanes[lane].document.undoManager?.canUndo == true
    }

    /// How the card that Undo brings back went away, so the view plays it backwards; `nil` where Undo
    /// has nothing to take back. The stream at rest has the card's grade behind it: the ring has gone
    /// down to the rest, and goes back up before the card returns.
    var undoReturn: UndoReturn? {
        guard canUndo, let from = destinations.last else { return nil }
        return UndoReturn(from: from, fromRest: isResting)
    }

    /// The grade Undo takes back, for the edge the card comes back by and the step the ring gives back; `nil`
    /// where the step gave none, a suspension.
    var undoReceipt: GradeReceipt? { receipts.last ?? nil }

    /// Takes back the last review or suspension of this stream, like Undo in the menu.
    func undoLast() {
        guard canUndo, let lane = stepLanes.last else { return }
        if lane != current {
            current = lane
            activateCurrentLane()
        }
        lanes[lane].document.undoManager?.undo()
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
    func sessionDriverDidMoveOn(_ moved: SessionDriver) {
        guard let index = lanes.firstIndex(where: { $0.driver === moved }) else { return }
        returnedByUndo = undoIsComing
        undoIsComing = false
        if returnedByUndo {
            // The card Undo brought back is asked again, in its own deck.
            current = index
        } else if index == current, !(moved.isResting && moved.rest.roundEnd != nil) {
            // After a grade: the most urgent card of all the decks, or this deck's rest when none has one.
            if let next = mostUrgentLane() { current = next }
        } else if index != current {
            // Another deck moved on its own (a change from the other device): nothing to ask yet.
            return
        }
        activateCurrentLane()
        questionNumber += 1
        stage = driver.isResting ? .resting : (returnedByUndo ? .revealed : .asking)
    }

    /// Undo or redo of a step: the steps of the stream are as many as the stream says now. A card
    /// that Undo brings back shows its answer.
    func sessionDriverDidRestore(_ restored: SessionDriver) {
        guard let index = lanes.firstIndex(where: { $0.driver === restored }) else { return }
        let steps = lanes.reduce(0) { $0 + $1.driver.stream.stepCount }
        let laneSteps = restored.stream.stepCount
        let counted = stepLanes.filter { $0 == index }.count
        if laneSteps < counted, let last = stepLanes.lastIndex(of: index) {
            stepLanes.remove(at: last)
        } else if laneSteps > counted {
            stepLanes.append(index)
        }
        destinations.removeLast(max(0, destinations.count - steps))
        while destinations.count < steps { destinations.append(.away) }
        receipts.removeLast(max(0, receipts.count - steps))
        while receipts.count < steps { receipts.append(nil) }
        undoIsComing = lanes[index].document.undoManager?.isUndoing == true
    }
}
