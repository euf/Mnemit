import Foundation

/// What "Study" opens: a stream of cards that doesn't end by itself, in segments. Every
/// grade is saved at once, so the segments are no sessions the learner has to finish:
/// leaving the stream anywhere loses nothing, and the next stream picks up from the deck.
///
/// 1. `Stage.plan`: today's plan, what `StudySession.counts(for:at:calendar:)` reports,
///    in the order and within the limits of `StudySession`, a share of the backlog
///    included (`DailyGoal.backlogShare(of:onTime:)`), taken in segments of at most
///    `cardsPerSession` cards. When a segment of the plan is done, the plan is looked at
///    again: the cards the segment left out come next, and cards of an Again come back as
///    learning cards. The segments are the stream's business: the plan the learner sees is
///    all of it.
/// 2. `Stage.rest`: the plan is empty, which is the daily goal. The stream waits here for
///    the learner, who can `keepGoing(in:at:calendar:)` or `addNewCards(_:in:at:calendar:)`.
/// 3. Beyond the plan, `Stage.catchUp`: the rest of the backlog. Its cards are due, so
///    reviewing them is not reviewing ahead. Cards that are not due are never reviewed: an
///    early review gains FSRS little, and more work is a new card (`addNewCards`).
/// 4. Then practice, which changes no card: `Stage.practiceMistakes` (today's mistakes,
///    `Deck.mistakes(onDayOf:calendar:)`), then `Stage.practiceNewest`
///    (`Deck.newestBatchIDs`) again and again.
///
/// New cards beyond the daily limits come only on request, as `addNewCards`.
///
/// Inside the plan the stream also rests twice a day at most (`DayRounds`): at the end of the
/// first round, which keeps the streak, and at the end of the last, which closes the ring while
/// the plan still has cards, as after a break. `restAtRoundEnd(roundsDone:rounds:)` looks at how
/// many rounds the cards done have ended, and `continueRound()` goes on. The rest holds the running segment, so no card is
/// lost or asked twice. Which round the learner has gone through is part of the value, as
/// everything else is, so undo and redo bring the rest back or take it away.
///
/// A stream from `init(practicingMistakesIn:at:calendar:random:)` or
/// `init(practicingNewestWordsIn:at:random:)` does one practice and then rests
/// (`isPracticeOnly`).
///
/// The stream is one value, so undo restores all of it: stage, segment and random state.
/// A segment is built from the deck as it is when the one before it ends, which the
/// driver calls `advance(in:at:calendar:)` for after it applied the last review.
public struct StudyStream: Sendable {
    public enum Stage: Sendable, Hashable {
        case plan
        /// The overdue reviews the plan left for the days after, see `StudyCounts.catchUp`.
        case catchUp
        case practiceMistakes
        case practiceNewest
        /// The plan is done, or the practice of a practice-only stream; no card is asked.
        case rest

        /// Practice changes no card.
        public var isPractice: Bool { self == .practiceMistakes || self == .practiceNewest }
    }

    /// What the plan segments (all segments of a practice-only stream) did, up to the
    /// last one that ended or was replaced. For the screen at rest.
    public struct Recap: Hashable, Sendable {
        public internal(set) var cards = 0
        public internal(set) var reviews = 0
        public internal(set) var recalled = 0

        /// Share of the reviews that recalled the card; `nil` without a review.
        public var accuracy: Double? {
            reviews > 0 ? Double(recalled) / Double(reviews) : nil
        }
    }

    /// How many new cards `addNewCards` adds at most.
    public static let newCardChunk = 10

    /// How many rounds of the day the learner has gone through: those that were done when the stream
    /// began, and those they went on from at a rest. A round done beyond it is a rest to come.
    public private(set) var roundsPassed = 0
    /// The number of rounds done at the rest the stream is at inside the plan, "Round 1 done"; `nil`
    /// when it is not at one. The segment goes on from here when `continueRound()` is called.
    public private(set) var roundRest: Int?

    /// Stays the same for the whole stream: undo of a review brings back the stream of
    /// that review, even from another segment.
    public let id = UUID()
    public private(set) var stage: Stage
    /// The segment now running; an empty one at rest.
    public private(set) var mode: SessionMode
    public private(set) var recap = Recap()
    /// The reviews and suspensions in the stream so far, in every segment: what undo takes
    /// back. Part of the value, so undo restores it with the rest.
    public private(set) var stepCount = 0
    /// How the study segments ask their cards.
    public let reviewMode: ReviewMode
    /// A stream of one practice, which then rests instead of going on.
    public let isPracticeOnly: Bool
    /// How many new cards the deck may introduce on the study day at most, next to its own limits;
    /// `nil` asks only the limits. For every segment of the plan, and for what the stream counts.
    public let newCardAllowance: Int?
    private var random: SeededRandom

    /// A stream that starts with today's plan, or at rest if the plan is empty.
    ///
    /// - Parameter newCardAllowance: The deck's share of the new cards of the day, see
    ///   `DailyProgress.newCardAllowances`.
    public init(
        deck: Deck, at now: Date, calendar: StudyCalendar, random: SeededRandom = SeededRandom(), reviewMode: ReviewMode = .typed,
        newCardAllowance: Int? = nil
    ) {
        var random = random
        let plan = StudySession(
            deck: deck, at: now, calendar: calendar, random: SeededRandom(seed: random.next()), reviewMode: reviewMode, newCardAllowance: newCardAllowance)
        self.reviewMode = reviewMode
        self.newCardAllowance = newCardAllowance
        isPracticeOnly = false
        stage = plan.session.isFinished ? .rest : .plan
        mode = .study(plan)
        self.random = random
    }

    /// A stream of one practice of the cards `deck` has mistakes on today.
    public init(practicingMistakesIn deck: Deck, at now: Date, calendar: StudyCalendar, random: SeededRandom = SeededRandom()) {
        self.init(practicing: deck.mistakes(onDayOf: now, calendar: calendar), as: .practiceMistakes, at: now, random: random)
    }

    /// A stream of one practice of `Deck.newestBatchIDs`.
    public init(practicingNewestWordsIn deck: Deck, at now: Date, random: SeededRandom = SeededRandom()) {
        self.init(practicing: deck.newestBatchIDs, as: .practiceNewest, at: now, random: random)
    }

    private init(practicing cardIDs: [Card.ID], as stage: Stage, at now: Date, random: SeededRandom) {
        var random = random
        let practice = Practice(practicing: cardIDs, at: now, random: SeededRandom(seed: random.next()))
        reviewMode = .typed
        isPracticeOnly = true
        newCardAllowance = nil
        self.stage = practice.session.isFinished ? .rest : stage
        mode = .practice(practice)
        self.random = random
    }

    /// The part of the segment that study and practice share.
    public var session: Session { mode.session }

    /// The stream waits for the learner: the plan is done, or the plan stops at the end of a round.
    public var isResting: Bool { stage == .rest || roundRest != nil }

    /// Grades the current card of the segment, see `SessionMode.grade(_:in:at:calendar:duration:)`.
    public mutating func grade(_ grade: Grade, in deck: Deck, at now: Date, calendar: StudyCalendar, duration: Duration? = nil) -> SessionMode.Outcome? {
        guard roundRest == nil else { return nil }
        let outcome = mode.grade(grade, in: deck, at: now, calendar: calendar, duration: duration)
        if outcome != nil { stepCount += 1 }
        return outcome
    }

    public mutating func perform(_ command: SessionCommand) {
        if case .suspend = command, session.currentCardID != nil { stepCount += 1 }
        mode.perform(command)
    }

    /// Moves on to the next segment if the one running has no card left to ask: the plan
    /// goes on while it isn't empty and rests once it is, the catch-up goes on into
    /// practice, practice repeats. Rest and a segment with a card change nothing.
    ///
    /// Call it with the deck as it is after the last review. A segment that has no card
    /// to ask is never installed, so a call can't loop.
    ///
    /// - Returns: Whether the stream moved on.
    @discardableResult
    public mutating func advance(in deck: Deck, at now: Date, calendar: StudyCalendar) -> Bool {
        guard session.isFinished else { return false }
        let next: [Stage]
        switch stage {
        case .rest:
            return false
        case .plan:
            next = [.plan]
        case .catchUp:
            next = isPracticeOnly ? [] : [.catchUp, .practiceMistakes, .practiceNewest]
        case .practiceMistakes:
            next = isPracticeOnly ? [] : [.practiceNewest]
        case .practiceNewest:
            // A pass without a review would repeat forever.
            next = isPracticeOnly || session.reviewCount == 0 ? [] : [.practiceNewest]
        }
        if !install(firstOf: next, in: deck, at: now, calendar: calendar) {
            rest(at: now)
        }
        return true
    }

    /// Starts the count of rounds at `rounds`: the rounds that are done before the stream is, which
    /// it doesn't rest for.
    public mutating func startRounds(at rounds: Int) {
        roundsPassed = max(0, rounds)
    }

    /// Rests inside the plan if the cards done have ended a round that the learner has not been
    /// through: `roundsDone` of the day's `rounds`. Only the first round of the day rests, which keeps
    /// the streak, and the last, which closes the ring; the last only while the plan has cards left,
    /// else the plan ends in the rest of the plan. Only the plan rests; call it as the driver moves
    /// on, with the deck as it is, so that redo, which brings a stream back to the moment after a
    /// review, finds the rest again.
    ///
    /// - Returns: Whether the stream rests now.
    @discardableResult
    public mutating func restAtRoundEnd(roundsDone: Int, rounds: Int) -> Bool {
        guard stage == .plan, !isPracticeOnly, roundRest == nil, roundsDone > roundsPassed else { return roundRest != nil }
        guard roundsPassed == 0 || roundsDone >= rounds else { return false }
        roundRest = roundsDone
        return true
    }

    /// From a rest at the end of a round, goes on with the next one.
    public mutating func continueRound() {
        guard let rounds = roundRest else { return }
        roundsPassed = rounds
        roundRest = nil
    }

    /// From rest, goes on beyond the plan: the rest of the backlog, else the
    /// practice of today's mistakes, else of the newest words.
    ///
    /// - Returns: Whether there was anything to go on with.
    @discardableResult
    public mutating func keepGoing(in deck: Deck, at now: Date, calendar: StudyCalendar) -> Bool {
        guard stage == .rest, !isPracticeOnly else { return false }
        return install(firstOf: [.catchUp, .practiceMistakes, .practiceNewest], in: deck, at: now, calendar: calendar)
    }

    /// Whether `keepGoing(in:at:calendar:)` has anything to go on with.
    public func canKeepGoing(in deck: Deck, at now: Date, calendar: StudyCalendar) -> Bool {
        var copy = self
        return copy.keepGoing(in: deck, at: now, calendar: calendar)
    }

    /// How many new cards beyond the daily limits `addNewCards` would add now: at most
    /// `newCardChunk`, fewer if the deck has fewer left that the lock and burying allow.
    public static func extraNewCards(in deck: Deck, at now: Date, calendar: StudyCalendar, newCardAllowance: Int? = nil) -> Int {
        let planned = StudySession.counts(for: deck, at: now, calendar: calendar, newCardAllowance: newCardAllowance).new
        return StudySession.counts(for: deck, at: now, calendar: calendar, extraNew: newCardChunk, newCardAllowance: newCardAllowance).new - planned
    }

    /// Replaces the running segment with the plan and `count` new cards beyond the limits.
    /// Nothing is lost: cards the replaced segment had left are still due.
    ///
    /// - Returns: Whether there was a card to ask; the stream stays as it was if not.
    @discardableResult
    public mutating func addNewCards(_ count: Int, in deck: Deck, at now: Date, calendar: StudyCalendar) -> Bool {
        guard !isPracticeOnly, count > 0 else { return false }
        let plan = StudySession(
            deck: deck, at: now, calendar: calendar, random: SeededRandom(seed: random.next()), reviewMode: reviewMode, extraNew: count,
            newCardAllowance: newCardAllowance)
        guard !plan.session.isFinished else { return false }
        continueRound()
        install(.study(plan), as: .plan)
        return true
    }

    // MARK: - Segments

    /// Installs the first of `stages` that has a card to ask.
    private mutating func install(firstOf stages: [Stage], in deck: Deck, at now: Date, calendar: StudyCalendar) -> Bool {
        for stage in stages {
            if let segment = segment(for: stage, in: deck, at: now, calendar: calendar) {
                install(segment, as: stage)
                return true
            }
        }
        return false
    }

    /// The segment of `stage` as the deck lets it start now; `nil` if it has no card.
    private mutating func segment(for stage: Stage, in deck: Deck, at now: Date, calendar: StudyCalendar) -> SessionMode? {
        let segmentRandom = SeededRandom(seed: random.next())
        let segment: SessionMode
        switch stage {
        case .plan:
            segment = .study(
                StudySession(deck: deck, at: now, calendar: calendar, random: segmentRandom, reviewMode: reviewMode, newCardAllowance: newCardAllowance))
        case .catchUp:
            segment = .study(StudySession(catchingUpIn: deck, at: now, calendar: calendar, random: segmentRandom, reviewMode: reviewMode))
        case .practiceMistakes:
            segment = .practice(Practice(practicing: deck.mistakes(onDayOf: now, calendar: calendar), at: now, random: segmentRandom))
        case .practiceNewest:
            segment = .practice(Practice(practicing: deck.newestBatchIDs, at: now, random: segmentRandom))
        case .rest:
            return nil
        }
        return segment.session.isFinished ? nil : segment
    }

    private mutating func install(_ segment: SessionMode, as stage: Stage) {
        absorbRecap()
        mode = segment
        self.stage = stage
    }

    private mutating func rest(at now: Date) {
        absorbRecap()
        roundRest = nil
        stage = .rest
        mode = .study(StudySession(cardIDs: [], at: now, random: SeededRandom(seed: random.next()), reviewMode: reviewMode))
    }

    /// Adds what the running segment did to the recap, before it goes.
    private mutating func absorbRecap() {
        guard stage == .plan || isPracticeOnly else { return }
        recap.cards += session.completedCount
        recap.reviews += session.reviewCount
        recap.recalled += session.recalledCount
    }
}
