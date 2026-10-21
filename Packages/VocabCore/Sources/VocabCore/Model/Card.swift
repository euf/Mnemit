import Foundation

/// How well the learner knew a card. Raw values match FSRS ratings 1–4.
public enum Grade: Int, Codable, Sendable, CaseIterable, Comparable {
    case again = 1
    case hard = 2
    case good = 3
    case easy = 4

    /// Every grade except `.again` counts as a successful recall.
    public var isRecall: Bool { self != .again }

    public static func < (lhs: Grade, rhs: Grade) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// Where a card currently is in its learning life cycle.
public enum LearningPhase: Sendable {
    /// After the first review, until the card has collected enough steps.
    case learning
    /// Learned; scheduled by FSRS in whole study days.
    case review
    /// After a lapse, until the card has collected enough steps again.
    case relearning
}

/// What the app knows about the learner's recall of a card: FSRS stability and
/// difficulty plus its phase and schedule.
public struct LearningState: Hashable, Sendable {
    public var phase: LearningPhase
    /// Steps collected since entering (re)learning. Unused in `.review`.
    public var step: Int
    /// Days until the probability of recall drops to 90 %.
    public var stability: Double
    /// Inherent difficulty of the card, between 1 (easy) and 10 (hard).
    public var difficulty: Double
    public var lastReview: Date
    public var due: Date
    public var reviews: Int
    public var lapses: Int

    public init(
        phase: LearningPhase,
        step: Int = 0,
        stability: Double,
        difficulty: Double,
        lastReview: Date,
        due: Date,
        reviews: Int = 0,
        lapses: Int = 0
    ) {
        self.phase = phase
        self.step = step
        self.stability = stability
        self.difficulty = difficulty
        self.lastReview = lastReview
        self.due = due
        self.reviews = reviews
        self.lapses = lapses
    }
}

extension LearningState {
    /// Far above any stability FSRS reaches in a lifetime of reviews, and far enough
    /// below the largest `Double` that further reviews keep it finite.
    static let maximumStability = 1e9
    /// For `step`, `reviews` and `lapses`: far above any real count, and far enough
    /// below `Int.max` that the next review can't overflow it.
    static let maximumCount = 1_000_000

    /// Clamps values into the ranges FSRS and `Scheduler` work with, for learning states
    /// from hand-edited or corrupt files.
    mutating func sanitize() {
        stability = stability.clamped(to: FSRS.minimumStability...Self.maximumStability)
        difficulty = difficulty.clamped(to: FSRS.difficultyRange)
        step = step.clamped(to: 0...Self.maximumCount)
        reviews = reviews.clamped(to: 0...Self.maximumCount)
        lapses = lapses.clamped(to: 0...Self.maximumCount)
    }
}

/// How a review was asked.
public enum ReviewMode: Sendable {
    /// The learner typed a response, and the app suggested a grade. The Mac asks so.
    case typed
    /// The learner revealed the answer and graded without a response.
    case revealed

    /// Share of the stability FSRS adds on a recall that the card keeps: all after a typed
    /// review, `revealedRecallWeight` (`LearningOptions.revealedRecallWeight`) after a
    /// revealed one. Applies neither to a lapse nor to a card's first review; see
    /// `Scheduler`.
    public func stabilityGainShare(revealedRecallWeight: Double) -> Double {
        switch self {
        case .typed: 1
        case .revealed: revealedRecallWeight
        }
    }
}

/// One review in a study session.
public struct ReviewLogEntry: Hashable, Sendable {
    public var date: Date
    public var grade: Grade
    /// A recalled revealed review may gain less stability, see
    /// `LearningOptions.revealedRecallWeight`.
    public var mode: ReviewMode

    public init(date: Date, grade: Grade, mode: ReviewMode = .typed) {
        self.date = date
        self.grade = grade
        self.mode = mode
    }
}

/// Which direction a card of a note asks: from the foreign word to the native one, or
/// the other way round.
public enum CardKind: String, Sendable, CaseIterable {
    /// Foreign → native: the learner recognizes the word.
    case recognition
    /// Native → foreign: the learner produces the word. A study session holds a new
    /// production card back until the recognition card of its note is learned, see
    /// `LearningOptions.productionUnlockDays`.
    case production
}

/// A question with its answer and an optional hint, asked from question to answer.
///
/// ID and creation date come with the card and stay; every other change goes through
/// `DeckChange`.
public struct Card: Identifiable, Hashable, Sendable {
    public let id: UUID
    /// The texts follow the rule of `CardText`; only `DeckChange.editingText` changes them.
    public internal(set) var question: String
    public internal(set) var answer: String
    /// Optional hint shown together with the question.
    public internal(set) var hint: String
    /// The key of the word the card belongs to, shared by its sibling cards; `nil` for a
    /// card on its own. Content like the texts: only `DeckChange.settingNote` changes it.
    public internal(set) var note: String?
    /// Which direction the card asks; only means something together with a `note`.
    public internal(set) var kind: CardKind?
    public let created: Date
    /// `nil` while the card has never been studied. Only `Scheduler` and
    /// `DeckChange` change it.
    public internal(set) var learningState: LearningState?
    /// The review log, oldest first. `FSRSOptimizer` computes parameters from it.
    public internal(set) var log: [ReviewLogEntry]
    /// When the learner last reset the learning state, in whole seconds; `nil` if never.
    /// A merge leaves out the reviews before it, which the other device may still hold
    /// (#273).
    public internal(set) var learningStateReset: Date?
    /// When the learner last changed the texts, the note or the kind of the card, in whole
    /// seconds; `nil` if never since it was created or since an app version without this
    /// stamp saved it. `Deck.apply(_:at:calendar:)` sets it, and undoing a change sets it
    /// again, so undo reaches the other device. A merge takes the content of a card
    /// from the version that changed it last.
    public internal(set) var contentChanged: Date?
    /// Whether the learner suspended the card (#290): it is never due, so no session asks
    /// it, until they resume it. Its learning state stays as it was meanwhile.
    public internal(set) var isSuspended: Bool
    /// When the learner last suspended or resumed the card, in whole seconds; `nil` if
    /// never. A merge takes `isSuspended` from the version that changed it last.
    public internal(set) var suspensionChanged: Date?

    /// A new card, never studied. `note` is trimmed; an empty one counts as none.
    public init(id: UUID = UUID(), text: CardText, note: String? = nil, kind: CardKind? = nil, created: Date) {
        self.init(
            id: id, question: text.question, answer: text.answer, hint: text.hint,
            note: Self.normalized(note), kind: kind, created: created, learningState: nil)
    }

    /// `note` without surrounding whitespace, `nil` if nothing is left.
    static func normalized(_ note: String?) -> String? {
        guard let note = note.map(CardText.trimmed), !note.isEmpty else { return nil }
        return note
    }

    /// A new card with unchecked texts, for `LegacyImporter` and tests.
    init(id: UUID = UUID(), question: String, answer: String, hint: String = "", created: Date) {
        self.init(id: id, question: question, answer: answer, hint: hint, created: created, learningState: nil)
    }

    /// A card with a learning state, for `DeckFile`, `LegacyImporter` and tests.
    init(
        id: UUID = UUID(),
        question: String,
        answer: String,
        hint: String = "",
        note: String? = nil,
        kind: CardKind? = nil,
        created: Date,
        learningState: LearningState?,
        log: [ReviewLogEntry] = [],
        learningStateReset: Date? = nil,
        isSuspended: Bool = false,
        suspensionChanged: Date? = nil,
        contentChanged: Date? = nil
    ) {
        self.id = id
        self.question = question
        self.answer = answer
        self.hint = hint
        self.note = note
        self.kind = kind
        self.created = created
        self.learningState = learningState
        self.log = log
        self.learningStateReset = learningStateReset
        self.isSuspended = isSuspended
        self.suspensionChanged = suspensionChanged
        self.contentChanged = contentChanged
    }

    public var isNew: Bool { learningState == nil }

    /// Whether the review log reaches back to the card's first review. Cards imported
    /// from MacVocTrain 1 with a learning state lack the reviews before the import.
    public var hasCompleteLog: Bool {
        !log.isEmpty && learningState?.reviews == log.count
    }

    /// New cards are always due, suspended cards never.
    public func isDue(at date: Date) -> Bool {
        guard !isSuspended else { return false }
        guard let learningState else { return true }
        return learningState.due <= date
    }

    /// Whether the card has lapsed `threshold` times or more; never for a threshold of 0.
    /// Derived from the lapse count, so it needs no flag in the deck file and no merge
    /// rule: every version of a card agrees on its lapses.
    public func isLeech(threshold: Int) -> Bool {
        threshold > 0 && (learningState?.lapses ?? 0) >= threshold
    }

    /// Whether the texts, the note or the kind differ from those of `other`.
    func hasOtherContent(than other: Card) -> Bool {
        question != other.question || answer != other.answer || hint != other.hint || note != other.note || kind != other.kind
    }

    /// The latest time anything was done to the card: created, edited, reset, suspended or
    /// resumed, reviewed. A merge weighs it against a deletion on the other device.
    var lastChange: Date {
        [created, contentChanged, learningStateReset, suspensionChanged, log.last?.date, learningState?.lastReview]
            .compactMap { $0 }.max() ?? created
    }

    /// Suspends the card like `DeckChange.settingSuspended`, at `now` in whole seconds.
    mutating func suspend(at now: Date) {
        isSuspended = true
        suspensionChanged = Date(timeIntervalSince1970: now.timeIntervalSince1970.rounded(.down))
    }

    /// Makes the card a new card again but keeps its content. Leaves
    /// `learningStateReset` to the caller: replaying a log resets the card, too.
    mutating func resetLearningState() {
        learningState = nil
        log = []
    }
}
