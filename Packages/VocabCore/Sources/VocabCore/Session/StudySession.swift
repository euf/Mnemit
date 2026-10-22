import Foundation

/// A session over the due cards; its reviews change their learning state. It runs
/// as `SessionMode.study`.
public struct StudySession: Sendable {
    /// The state shared with practice. Only this type changes it.
    public private(set) var session: Session

    /// Fuzzes the intervals of reviews. Kept apart from the order of the session, so
    /// a review doesn't change which card comes next. As part of the session's value,
    /// undoing a review restores it: the same review again yields the same due date.
    private var fuzzing: SeededRandom
    /// How the session asks its cards; every review records it in the card's log.
    public let reviewMode: ReviewMode

    /// A session over all cards of `deck` that are due at `now`.
    ///
    /// - Parameters:
    ///   - calendar: Counts the study days that order the cards. Each review gets a
    ///     calendar of its own, see `review(_:of:with:at:calendar:)`.
    ///   - random: Decides the selection and order of the cards and the fuzz of the
    ///     intervals; the same seed gives the same session.
    ///   - reviewMode: How the cards are asked: typed on the Mac, revealed on the
    ///     iPhone (#258).
    ///   - extraNew: How many new cards beyond the daily limits the session adds, see
    ///     `selectCards(from:at:calendar:extraNew:newCardAllowance:using:)`.
    ///   - newCardAllowance: How many new cards the deck may introduce on the study day, see
    ///     `selectCards(from:at:calendar:extraNew:newCardAllowance:using:)`.
    public init(
        deck: Deck, at now: Date, calendar: StudyCalendar, random: SeededRandom = SeededRandom(), reviewMode: ReviewMode = .typed, extraNew: Int = 0,
        newCardAllowance: Int? = nil
    ) {
        var random = random
        let ids = Self.selectCards(from: deck, at: now, calendar: calendar, extraNew: extraNew, newCardAllowance: newCardAllowance, using: &random)
        self.init(cardIDs: ids, at: now, random: random, reviewMode: reviewMode)
    }

    /// A session over every card that is due at `now`, the backlog beyond today's share of it
    /// (`DailyGoal.backlogShare(of:onTime:)`) included: what the stream goes on with once the plan is
    /// done. These cards are due, so their reviews are ordinary ones.
    public init(catchingUpIn deck: Deck, at now: Date, calendar: StudyCalendar, random: SeededRandom = SeededRandom(), reviewMode: ReviewMode = .typed) {
        var random = random
        let ids = Self.selectCards(from: deck, at: now, calendar: calendar, includingBacklog: true, using: &random)
        self.init(cardIDs: ids, at: now, random: random, reviewMode: reviewMode)
    }

    /// A session over cards that are not due yet, those the learner is least likely to
    /// recall now first, see `selectReviewAhead(from:at:calendar:using:)`. Its reviews
    /// are ordinary reviews: FSRS takes the early review into account.
    public init(reviewingAheadIn deck: Deck, at now: Date, calendar: StudyCalendar, random: SeededRandom = SeededRandom(), reviewMode: ReviewMode = .typed) {
        var random = random
        let ids = Self.selectReviewAhead(from: deck, at: now, calendar: calendar, using: &random)
        self.init(cardIDs: ids, at: now, random: random, reviewMode: reviewMode)
    }

    /// A session over `cardIDs` in their order of urgency, see `SessionQueue`.
    init(cardIDs: [Card.ID], at now: Date, random: SeededRandom, reviewMode: ReviewMode) {
        var random = random
        self.reviewMode = reviewMode
        fuzzing = SeededRandom(seed: random.next())
        session = Session(cardIDs: cardIDs, startedAt: now, random: random)
    }

    /// Reviews `card`, the current card, and moves on to the next one.
    ///
    /// The card leaves the session once it is in the review phase. A lapse that brings its
    /// lapses to `LearningOptions.leechThreshold`, or to a further multiple of it, makes it
    /// a leech: the returned card is suspended, and it leaves the session at once.
    ///
    /// - Parameter calendar: Counts the elapsed study days and the due date. It may
    ///   differ from the one the session started with, e.g. after the machine's time
    ///   zone changed (#186).
    /// - Parameter duration: How long the card was on screen; it goes into the review log
    ///   and has no say in the schedule.
    /// - Returns: `card` after the review, to be stored in the deck; `nil` if `card`
    ///   isn't the current card, e.g. because the session is finished.
    mutating func review(_ grade: Grade, of card: Card, with learningOptions: LearningOptions, at now: Date, calendar: StudyCalendar, duration: Duration? = nil) -> Card? {
        guard card.id == session.currentCardID else { return nil }
        let scheduler = Scheduler(learningOptions: learningOptions, calendar: calendar)
        var scheduled = scheduler.review(card, grade: grade, at: now, mode: reviewMode, duration: duration, using: &fuzzing)
        let becameLeech = Self.isNewLeech(scheduled, after: card, threshold: learningOptions.leechThreshold)
        if becameLeech { scheduled.suspend(at: now) }
        session.record(grade, isDone: scheduled.learningState?.phase == .review, isLeech: becameLeech, at: now)
        return scheduled
    }

    /// Whether the review that made `scheduled` out of `card` lapsed it onto the threshold
    /// or a multiple of it. A resumed leech is suspended again only at the next multiple.
    private static func isNewLeech(_ scheduled: Card, after card: Card, threshold: Int) -> Bool {
        guard threshold > 0, !card.isSuspended, let lapses = scheduled.learningState?.lapses else { return false }
        return lapses > (card.learningState?.lapses ?? 0) && lapses.isMultiple(of: threshold)
    }

    mutating func perform(_ command: SessionCommand) {
        session.perform(command)
    }

    /// How soon `selectCards` introduces a due card; the smallest comes first.
    /// Due review cards go before new cards, so new cards only fill the rest of a session
    /// and can't crowd out review cards whose recall probability keeps dropping.
    enum Urgency: Comparable {
        /// Cards in learning or relearning.
        case learning
        /// Cards in the review phase, lowest probability of recall first.
        case review(recallBucket: Double)
        case new
    }

    /// Recall probabilities are rounded down to steps of `1 / recallBuckets`, so
    /// review cards of similar urgency get mixed.
    static let recallBuckets = 50.0

    /// Due cards in the order of their `Urgency`, cards of the same urgency at
    /// random. At most `cardsPerSession` cards are selected.
    ///
    /// Cards of a note (`Card.note`) take part as follows:
    /// - A new production card waits until every recognition card of its note is in the
    ///   review phase with a scheduled interval of `productionUnlockDays` or more.
    /// - Siblings are buried: a new or review card is left out for the day if another
    ///   card of its note was reviewed on the current study day or is already selected.
    ///   Learning and relearning cards are never left out. Skipping changes no card.
    /// - New cards fill their limits in `newCardOrder`: production cards up to
    ///   `newProductionPerSession`, all others up to `newCardsPerSession`. The limits
    ///   hold for the study day: cards first reviewed on the current study day, in this
    ///   session or an earlier one, are subtracted from them.
    /// - The backlog, the review cards that were already due before the study day, takes
    ///   only its share of the day, lowest probability of recall first: see `backlogLeft`.
    ///   `includingBacklog` lifts that.
    /// - `newCardAllowance` is one more ceiling for the new cards of the study day, next to those
    ///   limits: the share of the day's new cards (`DailyGoal.newCardsAllowed`) that falls to this
    ///   deck. Cards first reviewed on the current study day count against it, too. `nil` asks only
    ///   the limits of the deck.
    /// - `extraNew` further new cards are taken beyond those limits and beyond
    ///   `cardsPerSession`, in the same order and under the same lock and burying: the
    ///   learner asked for them, see `StudyStream.addNewCards(_:in:at:calendar:)`.
    static func selectCards(
        from deck: Deck, at now: Date, calendar: StudyCalendar, extraNew: Int = 0, includingBacklog: Bool = false, newCardAllowance: Int? = nil,
        using random: inout SeededRandom
    ) -> [Card.ID] {
        selection(
            from: deck, at: now, calendar: calendar, extraNew: extraNew, includingBacklog: includingBacklog, newCardAllowance: newCardAllowance, using: &random
        ).cards.map(\.card.id)
    }

    /// The cards a review ahead asks: review cards that are not due yet, lowest probability
    /// of recall now first (the same buckets as `selectCards`, ties at random). Cards of
    /// one note are buried as for the plan: one card per note, none if another card of the
    /// note was reviewed on the current study day. A card reviewed today is left out, as
    /// no study day has passed since: its recall probability is still 1. New and
    /// suspended cards are never taken, nor are cards in (re)learning, which are due
    /// anyway; a new production card stays locked, as only review cards come here.
    static func selectReviewAhead(from deck: Deck, at now: Date, calendar: StudyCalendar, using random: inout SeededRandom) -> [Card.ID] {
        let scheduler = Scheduler(learningOptions: deck.learningOptions, calendar: calendar)
        let today = calendar.dayNumber(for: now)
        let reviewedToday = notesReviewed(onDayOf: now, in: deck, calendar: calendar)

        var candidates: [Candidate] = []
        for card in deck.cards where !card.isSuspended && !card.isDue(at: now) {
            guard let state = card.learningState, state.phase == .review, calendar.dayNumber(for: state.lastReview) != today else { continue }
            let r = scheduler.recallProbability(of: state, at: now)
            candidates.append(Candidate(card: card, urgency: .review(recallBucket: (r * recallBuckets).rounded(.down)), tieBreak: random.next()))
        }
        candidates.sort { ($0.urgency, $0.tieBreak) < ($1.urgency, $1.tieBreak) }

        var selected: [Card.ID] = []
        var selectedNotes = Set<String>()
        for candidate in candidates {
            let card = candidate.card
            if let note = card.note {
                if selectedNotes.contains(note) || (reviewedToday[note] ?? []).contains(where: { $0 != card.id }) { continue }
                selectedNotes.insert(note)
            }
            selected.append(card.id)
        }
        return selected
    }

    /// The plan of the study day of `now` over `deck`, by kind: the very selection of
    /// `selectCards`, so the counts can't drift from what a stream takes, but without the
    /// size `cardsPerSession` gives one session. That is the size of a segment of the stream,
    /// which takes the plan segment after segment; the plan, and the goal made of it, is all
    /// of it, so nothing the learner sees grows as the segments go.
    ///
    /// Learning cards, then review cards, then new cards fill the session, so the counts
    /// don't depend on the random tie breaks, only which card of a kind is taken does.
    public static func counts(for deck: Deck, at now: Date, calendar: StudyCalendar, extraNew: Int = 0, newCardAllowance: Int? = nil) -> StudyCounts {
        counts(for: deck, at: now, calendar: calendar, extraNew: extraNew, newCardAllowance: newCardAllowance, past: nil)
    }

    /// `counts(for:at:calendar:extraNew:newCardAllowance:)`, or with `past` the plan of a past
    /// study day, `now` being its end or its start: `deck` is seen as it was then, as far as it can
    /// be, which is that cards created later didn't exist and `nextDue` is not asked. `past` is the
    /// `DayIndex` of the same deck, so a caller that counts the plan of every day of a history
    /// doesn't go through every card's calendar days for each of them.
    static func counts(
        for deck: Deck, at now: Date, calendar: StudyCalendar, extraNew: Int = 0, newCardAllowance: Int? = nil, past: DayIndex?
    ) -> StudyCounts {
        // The seed is arbitrary: the session this counts has a random of its own.
        var random = SeededRandom(seed: 0)
        let (selected, catchUp) = selection(
            from: deck, at: now, calendar: calendar, extraNew: extraNew, newCardAllowance: newCardAllowance, capsSize: false, past: past, using: &random)
        var counts = StudyCounts()
        counts.catchUp = catchUp
        let startOfDay = calendar.start(ofDay: calendar.dayNumber(for: now))
        for candidate in selected {
            switch candidate.urgency {
            case .learning:
                counts.learning += 1
                if candidate.card.wasNew(before: startOfDay) { counts.learningFromNew += 1 }
            case .review: counts.review += 1
            case .new:
                if candidate.card.kind == .production { counts.newProduction += 1 } else { counts.newOther += 1 }
            }
        }

        guard past == nil else { return counts }

        // A card that is due but not selected is buried, and comes back on the next study day.
        let selectedIDs = Set(selected.map(\.card.id))
        let nextStudyDay = calendar.start(ofDay: calendar.dayNumber(for: now) + 1)
        for card in deck.cards where !card.isSuspended {
            guard let due = card.learningState?.due else { continue }
            let next = due > now ? due : (selectedIDs.contains(card.id) ? nil : nextStudyDay)
            if let next, next < counts.nextDue ?? .distantFuture { counts.nextDue = next }
        }
        return counts
    }

    /// The cards of a session in the order of their `Urgency`, and how many overdue review cards the
    /// share of the backlog leaves for the days after (`StudyCounts.catchUp`).
    private static func selection(
        from deck: Deck, at now: Date, calendar: StudyCalendar, extraNew: Int = 0, includingBacklog: Bool = false, newCardAllowance: Int? = nil,
        capsSize: Bool = true, past: DayIndex? = nil, using random: inout SeededRandom
    ) -> (cards: [Candidate], catchUp: Int) {
        let options = deck.learningOptions
        let scheduler = Scheduler(learningOptions: options, calendar: calendar)
        let day = calendar.dayNumber(for: now)
        let lockedNotes = past?.lockedNotes ?? notesAwaitingRecognition(in: deck, calendar: calendar)
        let reviewedToday = past.map { $0.reviewedNotes[day] ?? [:] } ?? notesReviewed(onDayOf: now, in: deck, calendar: calendar)
        let startOfDay = calendar.start(ofDay: day)

        var due: [Candidate] = []
        var new: [Candidate] = []
        for card in deck.cards where card.isDue(at: now) {
            // A card that is created after a past day was no part of its plan.
            if let past, !past.countsCardsCreatedLater, card.isNew, card.created > now { continue }
            let urgency: Urgency
            if let learningState = card.learningState {
                if learningState.phase == .review {
                    let r = scheduler.recallProbability(of: learningState, at: now)
                    urgency = .review(recallBucket: (r * recallBuckets).rounded(.down))
                } else {
                    urgency = .learning
                }
            } else {
                if card.kind == .production, let note = card.note, lockedNotes.contains(note) { continue }
                urgency = .new
            }
            var candidate = Candidate(card: card, urgency: urgency, tieBreak: random.next())
            if case .review = urgency, let dueDate = card.learningState?.due, dueDate < startOfDay { candidate.isBacklog = true }
            if case .new = urgency { new.append(candidate) } else { due.append(candidate) }
        }
        due.sort { ($0.urgency, $0.tieBreak) < ($1.urgency, $1.tieBreak) }
        if options.newCardOrder == .newestFirst {
            // Stable: cards created together stay in deck order.
            new = new.enumerated().sorted { ($1.element.card.created, $0.offset) < ($0.element.card.created, $1.offset) }.map(\.element)
        }

        var selected: [Candidate] = []
        var selectedNotes = Set<String>()
        let introduced = past.map { $0.introduced[day] ?? (production: 0, other: 0) } ?? newCardsIntroduced(onDayOf: now, in: deck, calendar: calendar)
        var newLeft = max(0, (options.newCardsPerSession ?? Int.max) - introduced.other)
        var productionLeft = max(0, (options.newProductionPerSession ?? Int.max) - introduced.production)
        var allowanceLeft = newCardAllowance.map { max(0, $0 - introduced.production - introduced.other) } ?? Int.max
        let overdue = due.reduce(0) { $0 + ($1.isBacklog ? 1 : 0) }
        let onTime = due.reduce(0) { $0 + (!$1.isBacklog && $1.urgency != .learning ? 1 : 0) }
        var backlogLeft =
            includingBacklog ? Int.max : backlogShareLeft(overdue: overdue, onTime: onTime, in: deck, at: now, scheduler: scheduler, calendar: calendar)
        var backlogTaken = 0
        let sizeLimit = capsSize ? options.cardsPerSession ?? Int.max : Int.max
        for candidate in due + new where selected.count < sizeLimit {
            let card = candidate.card
            if candidate.urgency != .learning, let note = card.note {
                let buried = selectedNotes.contains(note) || (reviewedToday[note] ?? []).contains { $0 != card.id }
                if buried { continue }
            }
            if candidate.isBacklog {
                guard backlogLeft > 0 else { continue }
                backlogLeft -= 1
                backlogTaken += 1
            }
            if candidate.urgency == .new {
                guard allowanceLeft > 0 else { continue }
                if card.kind == .production {
                    guard productionLeft > 0 else { continue }
                    productionLeft -= 1
                } else {
                    guard newLeft > 0 else { continue }
                    newLeft -= 1
                }
                allowanceLeft -= 1
            }
            selected.append(candidate)
            if let note = card.note { selectedNotes.insert(note) }
        }

        var extraLeft = extraNew
        if extraLeft > 0 {
            let selectedIDs = Set(selected.map(\.card.id))
            for candidate in new where extraLeft > 0 && !selectedIDs.contains(candidate.card.id) {
                let card = candidate.card
                if let note = card.note {
                    guard !selectedNotes.contains(note), !(reviewedToday[note] ?? []).contains(where: { $0 != card.id }) else { continue }
                    selectedNotes.insert(note)
                }
                selected.append(candidate)
                extraLeft -= 1
            }
        }

        let ordered = selected.sorted { ($0.urgency, $0.tieBreak) < ($1.urgency, $1.tieBreak) }
        return (ordered, includingBacklog ? 0 : overdue - backlogTaken)
    }

    private struct Candidate {
        var card: Card
        var urgency: Urgency
        var tieBreak: UInt64
        /// A review card that was already due before the study day: the backlog.
        var isBacklog = false
    }

    /// How many cards of the backlog today takes: `DailyGoal.backlogShare(of:onTime:)` of the
    /// backlog and of the review cards due on the day, both as the study day began, less the
    /// cards of the backlog already reviewed today, so the share stays the same however far
    /// it is worked off.
    ///
    /// Both counts of the day's start are what is there now, `overdue` and `onTime`, plus what
    /// was reviewed since and was there then: the cards whose log, replayed up to the day's
    /// start, leaves a review card due before the day (the backlog) or on it. Nothing is
    /// replayed while no card is overdue.
    private static func backlogShareLeft(overdue: Int, onTime: Int, in deck: Deck, at now: Date, scheduler: Scheduler, calendar: StudyCalendar) -> Int {
        guard overdue > 0 else { return 0 }
        let day = calendar.dayNumber(for: now)
        let start = calendar.start(ofDay: day)
        let end = calendar.start(ofDay: day + 1)
        var clearedBacklog = 0
        var clearedOnTime = 0
        for card in deck.cards where card.hasCompleteLog {
            let before = card.log.prefix { $0.date < start }
            // Reviewed on this study day up to `now`, and before it.
            guard !before.isEmpty, before.count < card.log.count, card.log[before.count].date <= now else { continue }
            guard let state = scheduler.replaying(Array(before), of: card).learningState, state.phase == .review else { continue }
            if state.due < start {
                clearedBacklog += 1
            } else if state.due < end {
                clearedOnTime += 1
            }
        }
        return max(0, DailyGoal.backlogShare(of: overdue + clearedBacklog, onTime: onTime + clearedOnTime) - clearedBacklog)
    }

    /// The notes with a recognition card that isn't learned yet, so their production cards
    /// stay locked; none if `productionUnlockDays` is 0. A card is learned in the review
    /// phase once its scheduled interval, from the last review to the due date, has
    /// reached `productionUnlockDays`.
    static func notesAwaitingRecognition(in deck: Deck, calendar: StudyCalendar) -> Set<String> {
        let unlockDays = deck.learningOptions.productionUnlockDays
        guard unlockDays > 0 else { return [] }
        var notes = Set<String>()
        for card in deck.cards where card.kind == .recognition {
            guard let note = card.note else { continue }
            if let state = card.learningState, state.phase == .review, calendar.days(from: state.lastReview, to: state.due) >= unlockDays {
                continue
            }
            notes.insert(note)
        }
        return notes
    }

    /// The cards introduced on the study day of `date`, production cards apart from all
    /// others: those whose first review fell on it, whatever became of them since. A card
    /// whose log doesn't reach back to its first review (an import from MacVocTrain 1)
    /// says nothing about when it was introduced and doesn't count.
    private static func newCardsIntroduced(onDayOf date: Date, in deck: Deck, calendar: StudyCalendar) -> (production: Int, other: Int) {
        let today = calendar.dayNumber(for: date)
        var introduced = (production: 0, other: 0)
        for card in deck.cards {
            guard card.hasCompleteLog, let first = card.log.first, calendar.dayNumber(for: first.date) == today else { continue }
            if card.kind == .production { introduced.production += 1 } else { introduced.other += 1 }
        }
        return introduced
    }

    /// For each note, the cards reviewed on the study day of `date`.
    private static func notesReviewed(onDayOf date: Date, in deck: Deck, calendar: StudyCalendar) -> [String: Set<Card.ID>] {
        let today = calendar.dayNumber(for: date)
        var reviewed: [String: Set<Card.ID>] = [:]
        for card in deck.cards {
            guard let note = card.note, let lastReview = card.learningState?.lastReview, calendar.dayNumber(for: lastReview) == today else { continue }
            reviewed[note, default: []].insert(card.id)
        }
        return reviewed
    }

    /// What the selection asks of the cards of a deck, day by day, as `selection` finds out for
    /// one day (`newCardsIntroduced`, `notesReviewed`, `notesAwaitingRecognition`), gathered once
    /// for every day: the plan of a past study day (`counts(for:at:calendar:extraNew:past:)`)
    /// then needs no pass over the cards through the calendar, and a streak over years of
    /// history is cheap.
    struct DayIndex: Sendable {
        let lockedNotes: Set<String>
        /// The cards whose first review fell on a day, production cards apart from all others.
        let introduced: [Int: (production: Int, other: Int)]
        /// The cards of each note whose last review fell on a day.
        let reviewedNotes: [Int: [String: Set<Card.ID>]]
        /// Whether a new card created after the day counts as one of its plan: for the new cards a
        /// day could take if it began now (`DeckActivity.history`).
        let countsCardsCreatedLater: Bool

        /// The index of a deck at the start of a study day: nothing was introduced or reviewed on the
        /// day yet, and `lockedNotes` are the notes whose production cards are held back.
        init(lockedNotes: Set<String>, countsCardsCreatedLater: Bool = false) {
            self.lockedNotes = lockedNotes
            introduced = [:]
            reviewedNotes = [:]
            self.countsCardsCreatedLater = countsCardsCreatedLater
        }

        init(deck: Deck, calendar: StudyCalendar) {
            countsCardsCreatedLater = false
            lockedNotes = StudySession.notesAwaitingRecognition(in: deck, calendar: calendar)
            var introduced: [Int: (production: Int, other: Int)] = [:]
            var reviewed: [Int: [String: Set<Card.ID>]] = [:]
            for card in deck.cards {
                if card.hasCompleteLog, let first = card.log.first {
                    let day = calendar.dayNumber(for: first.date)
                    var count = introduced[day] ?? (production: 0, other: 0)
                    if card.kind == .production { count.production += 1 } else { count.other += 1 }
                    introduced[day] = count
                }
                if let note = card.note, let lastReview = card.learningState?.lastReview {
                    reviewed[calendar.dayNumber(for: lastReview), default: [:]][note, default: []].insert(card.id)
                }
            }
            self.introduced = introduced
            reviewedNotes = reviewed
        }
    }
}

/// The plan of a study day as it stands at some moment, by kind: the cards a stream started
/// then would take, see `StudySession.counts(for:at:calendar:)`. At the start of the day its
/// `total` is the daily goal, later the cards left.
public struct StudyCounts: Hashable, Sendable {
    /// Never-studied production cards (`CardKind.production`), within
    /// `newProductionPerSession`.
    public internal(set) var newProduction = 0
    /// All other never-studied cards, within `newCardsPerSession`.
    public internal(set) var newOther = 0
    /// Cards in learning or relearning.
    public internal(set) var learning = 0
    /// Cards in the review phase.
    public internal(set) var review = 0
    /// Of `learning`, the cards that were new when the study day began: a new card started
    /// today and still in its learning steps.
    public internal(set) var learningFromNew = 0
    /// Overdue review cards, due before the study day, that the plan leaves for the days after:
    /// what is beyond the share the backlog asks of a day (`DailyGoal.backlogShare(of:onTime:)`). The
    /// stream goes on with them once the plan is done (`StudyStream.Stage.catchUp`).
    public internal(set) var catchUp = 0
    /// When something comes back that today's counts leave out: the first learning or
    /// review date after now, or the next study day for a card that is due but buried.
    /// `nil` if no card has been studied. Meant for `total == 0`.
    public internal(set) var nextDue: Date?

    public var new: Int { newProduction + newOther }

    /// The cards that were new when the study day began: `new`, and the new cards started
    /// today that are still in learning (`learningFromNew`). What the time left prices as new
    /// (`DailyGoal.minutesLeft(newCards:otherCards:pace:)`).
    public var newAtDayStart: Int { new + learningFromNew }

    /// The cards of the plan: all of them at the start of the day (the daily goal), the cards
    /// left later ("N cards left"). `cardsPerSession` doesn't cap it: it is the size of a
    /// segment of the stream.
    public var total: Int { new + learning + review }
}
