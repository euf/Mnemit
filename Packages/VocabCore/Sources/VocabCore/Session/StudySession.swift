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
    public init(deck: Deck, at now: Date, calendar: StudyCalendar, random: SeededRandom = SeededRandom(), reviewMode: ReviewMode = .typed) {
        self.reviewMode = reviewMode
        var random = random
        let ids = Self.selectCards(from: deck, at: now, calendar: calendar, using: &random)
        fuzzing = SeededRandom(seed: random.next())
        session = Session(cardIDs: ids, startedAt: now, random: random)
    }

    /// Reviews `card`, the current card, and moves on to the next one.
    ///
    /// The card leaves the session once it is in the review phase.
    ///
    /// - Parameter calendar: Counts the elapsed study days and the due date. It may
    ///   differ from the one the session started with, e.g. after the machine's time
    ///   zone changed (#186).
    /// - Returns: `card` after the review, to be stored in the deck; `nil` if `card`
    ///   isn't the current card, e.g. because the session is finished.
    mutating func review(_ grade: Grade, of card: Card, with learningOptions: LearningOptions, at now: Date, calendar: StudyCalendar) -> Card? {
        guard card.id == session.currentCardID else { return nil }
        let scheduler = Scheduler(learningOptions: learningOptions, calendar: calendar)
        let scheduled = scheduler.review(card, grade: grade, at: now, mode: reviewMode, using: &fuzzing)
        session.record(grade, isDone: scheduled.learningState?.phase == .review, at: now)
        return scheduled
    }

    mutating func perform(_ command: SessionCommand) {
        session.perform(command)
    }

    /// How soon `selectCards` introduces a due card; the smallest comes first.
    /// Due reviews go before new cards, so new cards only fill the rest of a session
    /// and can't crowd out reviews whose recall probability keeps dropping.
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
    ///   `newProductionPerSession`, all others up to `newCardsPerSession`.
    static func selectCards(from deck: Deck, at now: Date, calendar: StudyCalendar, using random: inout SeededRandom) -> [Card.ID] {
        selection(from: deck, at: now, calendar: calendar, using: &random).map(\.card.id)
    }

    /// What a session over `deck` started at `now` would take, by kind: the very
    /// selection of `selectCards`, so the counts can't drift from the session.
    ///
    /// Learning cards, then reviews, then new cards fill the session, so the counts
    /// don't depend on the random tie breaks, only which card of a kind is taken does.
    public static func counts(for deck: Deck, at now: Date, calendar: StudyCalendar) -> StudyCounts {
        // The seed is arbitrary: the session this counts has a random of its own.
        var random = SeededRandom(seed: 0)
        let selected = selection(from: deck, at: now, calendar: calendar, using: &random)
        var counts = StudyCounts()
        for candidate in selected {
            switch candidate.urgency {
            case .learning: counts.learning += 1
            case .review: counts.review += 1
            case .new:
                if candidate.card.kind == .production { counts.newProduction += 1 } else { counts.newOther += 1 }
            }
        }

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

    private static func selection(from deck: Deck, at now: Date, calendar: StudyCalendar, using random: inout SeededRandom) -> [Candidate] {
        let options = deck.learningOptions
        let scheduler = Scheduler(learningOptions: options, calendar: calendar)
        let lockedNotes = notesAwaitingRecognition(in: deck, calendar: calendar)
        let reviewedToday = notesReviewed(onDayOf: now, in: deck, calendar: calendar)

        var due: [Candidate] = []
        var new: [Candidate] = []
        for card in deck.cards where card.isDue(at: now) {
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
            let candidate = Candidate(card: card, urgency: urgency, tieBreak: random.next())
            if case .new = urgency { new.append(candidate) } else { due.append(candidate) }
        }
        due.sort { ($0.urgency, $0.tieBreak) < ($1.urgency, $1.tieBreak) }
        if options.newCardOrder == .newestFirst {
            // Stable: cards created together stay in deck order.
            new = new.enumerated().sorted { ($1.element.card.created, $0.offset) < ($0.element.card.created, $1.offset) }.map(\.element)
        }

        var selected: [Candidate] = []
        var selectedNotes = Set<String>()
        var newLeft = options.newCardsPerSession ?? Int.max
        var productionLeft = options.newProductionPerSession ?? Int.max
        for candidate in due + new where selected.count < (options.cardsPerSession ?? Int.max) {
            let card = candidate.card
            if candidate.urgency != .learning, let note = card.note {
                let buried = selectedNotes.contains(note) || (reviewedToday[note] ?? []).contains { $0 != card.id }
                if buried { continue }
            }
            if candidate.urgency == .new {
                if card.kind == .production {
                    guard productionLeft > 0 else { continue }
                    productionLeft -= 1
                } else {
                    guard newLeft > 0 else { continue }
                    newLeft -= 1
                }
            }
            selected.append(candidate)
            if let note = card.note { selectedNotes.insert(note) }
        }

        return selected.sorted { ($0.urgency, $0.tieBreak) < ($1.urgency, $1.tieBreak) }
    }

    private struct Candidate {
        var card: Card
        var urgency: Urgency
        var tieBreak: UInt64
    }

    /// The notes with a recognition card that isn't learned yet, so their production cards
    /// stay locked; none if `productionUnlockDays` is 0. A card is learned in the review
    /// phase once its scheduled interval, from the last review to the due date, has
    /// reached `productionUnlockDays`.
    private static func notesAwaitingRecognition(in deck: Deck, calendar: StudyCalendar) -> Set<String> {
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
}

/// How many cards a study session started now would take, see
/// `StudySession.counts(for:at:calendar:)`.
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
    /// When something comes back that today's counts leave out: the first learning or
    /// review date after now, or the next study day for a card that is due but buried.
    /// `nil` if no card has been studied. Meant for `total == 0`.
    public internal(set) var nextDue: Date?

    public var new: Int { newProduction + newOther }

    /// The size of the session, which `cardsPerSession` has already capped.
    public var total: Int { new + learning + review }
}
