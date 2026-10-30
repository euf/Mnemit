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
    /// The learner typed a response, and the app suggested a grade. Upstream's Mac app asked so;
    /// the log keeps those reviews readable, and nothing records a new one.
    case typed
    /// The learner revealed the answer and graded without a response: every review of the app.
    case revealed
}

/// One review in a study session.
public struct ReviewLogEntry: Hashable, Sendable {
    public var date: Date
    public var grade: Grade
    /// How the card was asked; the scheduler treats both modes alike.
    public var mode: ReviewMode
    /// How long the card was on screen before it was graded, in whole milliseconds (the unit of
    /// `reviews.jsonl`); `nil` where the time wasn't measured, as in every review before it was.
    /// It only feeds the pace (`DailyGoal.pace`); scheduling never reads it.
    public var duration: Duration?

    public init(date: Date, grade: Grade, mode: ReviewMode = .typed, duration: Duration? = nil) {
        self.date = date
        self.grade = grade
        self.mode = mode
        self.duration = duration.map { .milliseconds(max(0, Int(($0 / .milliseconds(1)).rounded()))) }
    }
}

/// A review as a merge and the review log compare it: at whole seconds, as `reviews.jsonl` stores it.
struct ReviewKey: Hashable, Comparable, Sendable {
    var second: Int
    var grade: Grade

    init(_ entry: ReviewLogEntry) {
        second = Int(entry.date.timeIntervalSince1970.rounded(.down))
        grade = entry.grade
    }

    init(second: Int, grade: Grade) {
        self.second = second
        self.grade = grade
    }

    static func < (lhs: ReviewKey, rhs: ReviewKey) -> Bool {
        (lhs.second, lhs.grade) < (rhs.second, rhs.grade)
    }
}

/// Which direction a card of a note asks: from the foreign word to the native one, or
/// the other way round.
public enum CardKind: String, Sendable, CaseIterable {
    /// Foreign → native: the learner recognizes the word.
    case recognition
    /// Native → foreign: the learner produces the word. A study session holds a new
    /// production card back until the recognition card of its note is learned, see
    /// `StudySession.unlockDays`.
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
    /// The image and the sound of each side, as names of files in the deck's media
    /// (`DeckMedia`); `nil` for a side without one. Content like the texts: only
    /// `DeckChange.settingMedia` changes them, and a merge takes them from the version that
    /// changed the content last.
    public internal(set) var questionImage: String?
    public internal(set) var questionAudio: String?
    public internal(set) var answerImage: String?
    public internal(set) var answerAudio: String?
    public internal(set) var created: Date
    /// `nil` while the card has never been studied. Only `Scheduler` and
    /// `DeckChange` change it.
    public internal(set) var learningState: LearningState?
    /// The review log, oldest first. `FSRSOptimizer` computes parameters from it.
    public internal(set) var log: [ReviewLogEntry]
    /// The reviews the learner took back with Undo, oldest first, each once. They are not in `log`, which holds the
    /// reviews that stand and so feeds the schedule, the statistics and the optimizer unchanged. A merge keeps them
    /// out of the log: without this note, a review one version holds and the other lacks looks the same whether the
    /// other took it back or has not seen it yet. Reviews before `learningStateReset` drop out of it as out of the log.
    var undone: [ReviewKey]
    /// When the learner last reset the learning state, in whole seconds; `nil` if never.
    /// A merge leaves out the reviews before it, which the other device may still hold
    /// (#273).
    public internal(set) var learningStateReset: Date?
    /// When the learner last changed the texts, the media, the note, the kind or the addition (`created`, see
    /// `DeckChange.renewing(_:in:at:)`) of the card, in whole
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

    /// A new card with unchecked texts, for tests.
    init(id: UUID = UUID(), question: String, answer: String, hint: String = "", created: Date) {
        self.init(id: id, question: question, answer: answer, hint: hint, created: created, learningState: nil)
    }

    /// A card with a learning state, for `DeckFile` and tests.
    init(
        id: UUID = UUID(),
        question: String,
        answer: String,
        hint: String = "",
        note: String? = nil,
        kind: CardKind? = nil,
        media: CardMedia = CardMedia(),
        created: Date,
        learningState: LearningState?,
        log: [ReviewLogEntry] = [],
        learningStateReset: Date? = nil,
        isSuspended: Bool = false,
        suspensionChanged: Date? = nil,
        contentChanged: Date? = nil,
        undone: [ReviewKey] = []
    ) {
        self.id = id
        self.question = question
        self.answer = answer
        self.hint = hint
        self.note = note
        self.kind = kind
        questionImage = media.questionImage
        questionAudio = media.questionAudio
        answerImage = media.answerImage
        answerAudio = media.answerAudio
        self.created = created
        self.learningState = learningState
        self.log = log
        self.undone = undone
        self.learningStateReset = learningStateReset
        self.isSuspended = isSuspended
        self.suspensionChanged = suspensionChanged
        self.contentChanged = contentChanged
    }

    public var isNew: Bool { learningState == nil }

    /// The media of the card, the four slots together.
    public var media: CardMedia {
        get { CardMedia(questionImage: questionImage, questionAudio: questionAudio, answerImage: answerImage, answerAudio: answerAudio) }
        set {
            questionImage = newValue.questionImage
            questionAudio = newValue.questionAudio
            answerImage = newValue.answerImage
            answerAudio = newValue.answerAudio
        }
    }

    /// Whether the review log reaches back to the card's first review. Cards imported
    /// from MacVocTrain 1 with a learning state lack the reviews before the import.
    public var hasCompleteLog: Bool {
        !log.isEmpty && learningState?.reviews == log.count
    }

    /// Whether the log has fewer lines than the card has had reviews and stops before the last of them: the
    /// card's learning state holds a review the log lacks, so lines of `reviews.jsonl` went missing. A log that
    /// is short because it starts after an import from MacVocTrain 1 ends with the last review.
    var hasLostReviews: Bool {
        guard let state = learningState, let last = log.last, log.count < state.reviews else { return false }
        return ReviewKey(last).second < Int(state.lastReview.timeIntervalSince1970.rounded(.down))
    }

    /// Whether the card was new at `start`, say when a study day began: it had no review before.
    /// A log that doesn't reach back to the first review (`hasCompleteLog`) can't tell, and says
    /// the card was not.
    func wasNew(before start: Date) -> Bool {
        learningState == nil || (hasCompleteLog && log[0].date >= start)
    }

    /// How many of the card's reviews on the study day of `now` asked it in the review phase: the ones that count
    /// against Maximum reviews/day (`LearningOptions.maximumReviewsPerDay`). A lapse counts, the relearning after it
    /// does not. The phase comes from the grades alone, replayed from the first review as `credit(onDayOf:calendar:steps:)`
    /// does; a log that doesn't reach back to it (`hasCompleteLog`) starts as a review card.
    func reviewPhaseReviews(onDayOf now: Date, calendar: StudyCalendar, steps required: Int) -> Int {
        let day = calendar.dayNumber(for: now)
        var phase: LearningPhase = hasCompleteLog || log.isEmpty ? .learning : .review
        var steps = Steps(required: required)
        var count = 0
        for entry in log {
            if phase == .review {
                if calendar.dayNumber(for: entry.date) == day { count += 1 }
                if entry.grade == .again { (phase, steps) = (.relearning, Steps(required: required)) }
            } else {
                steps.apply(entry.grade)
                if steps.areEnough { (phase, steps) = (.review, Steps(required: required)) }
            }
        }
        return count
    }

    /// New cards are always due, suspended cards never.
    public func isDue(at date: Date) -> Bool {
        guard !isSuspended else { return false }
        guard let learningState else { return true }
        return learningState.due <= date
    }

    /// How often the learner forgot the card, for the leech rule: every Forgot in the log but the first answer, which only
    /// says the card is new. `lapses` counts the Forgots of the review phase alone, and a card forgotten in its learning
    /// steps again and again stays below any threshold; the log holds them all. A log that doesn't reach back to the first
    /// review (`hasCompleteLog`) may hold fewer, and the stored lapses stand for the rest.
    var forgotCount: Int {
        max(learningState?.lapses ?? 0, log.dropFirst().count { $0.grade == .again })
    }

    /// Whether the card was forgotten `threshold` times or more (`forgotCount`); never for a threshold of 0.
    /// Derived from the log and the lapse count, so it needs no flag in the deck file and no merge
    /// rule: every version of a card agrees on its Forgots.
    public func isLeech(threshold: Int) -> Bool {
        threshold > 0 && forgotCount >= threshold
    }

    /// What makes two cards ask the same, for finding duplicates: the key of the question text
    /// (`CardText.key(forQuestion:)`), or, for a question without a text, which an image or a
    /// sound can make up, the names of those files: every such question would be the same
    /// otherwise.
    var questionKey: String {
        let key = CardText.key(forQuestion: question)
        guard key.isEmpty else { return key }
        return "\u{0}" + [questionImage, questionAudio].compactMap { $0 }.joined(separator: "|")
    }

    /// Whether the texts, the media, the note or the kind differ from those of `other`.
    func hasOtherContent(than other: Card) -> Bool {
        question != other.question || answer != other.answer || hint != other.hint || note != other.note || kind != other.kind || media != other.media
            || created != other.created
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

    /// Takes over what a review changes of `other`: the learning state and the log, the stamp of the
    /// last reset, and whether the card is suspended (a review may make it a leech). The content stays.
    mutating func takeLearning(from other: Card) {
        learningState = other.learningState
        log = other.log
        learningStateReset = other.learningStateReset
        isSuspended = other.isSuspended
        suspensionChanged = other.suspensionChanged
    }

    // MARK: - Taking back a review

    /// Takes back `entry`, a review of this card that stands in its log, and keeps a note of it (`undone`), so a
    /// merge with a version that saw it doesn't bring it back. Only that review goes: the reviews other versions
    /// added meanwhile stay, and so do a reset and a suspension made since.
    ///
    /// - Parameter before: The card as it was before the review. If the log is as it was with the review added,
    ///   nothing changed since and the card is `before` exactly, fuzz included. Otherwise the log without the
    ///   review is replayed, or, for a log that doesn't reach back to the first review (`hasCompleteLog`),
    ///   the count of reviews goes down by one and the learning state stays.
    mutating func takeBack(_ entry: ReviewLogEntry, before: Card, scheduler: Scheduler) {
        let key = ReviewKey(entry)
        undone = (undone.filter { $0 != key } + [key]).sorted()
        guard let index = log.lastIndex(where: { ReviewKey($0) == key }) else { return }
        var rest = log
        rest.remove(at: index)
        if rest == before.log {
            learningState = before.learningState
            log = before.log
        } else {
            adopt(rest, scheduler: scheduler)
        }
        // The review made the card a leech and suspended it: taking it back resumes the card.
        if isSuspended, suspensionChanged == Self.wholeSeconds(entry.date) {
            isSuspended = before.isSuspended
            suspensionChanged = before.suspensionChanged
        }
    }

    /// Puts `entry` back into the log after `takeBack(_:before:scheduler:)` took it, and drops the note of it. If the
    /// log is as it was after the review, that card, `after`, comes back exactly; else the log with the review
    /// is replayed, as in `takeBack`.
    ///
    /// ponytail: another device that merged the note in takes the review back again at its next merge; a stamp per
    /// entry would settle that. It takes an Undo, a save the other device read, and a Redo after that.
    mutating func putBack(_ entry: ReviewLogEntry, after: Card, scheduler: Scheduler) {
        let key = ReviewKey(entry)
        undone.removeAll { $0 == key }
        guard !log.contains(where: { ReviewKey($0) == key }) else { return }
        var all = log
        all.insert(entry, at: all.firstIndex { $0.date > entry.date } ?? all.endIndex)
        if all == after.log {
            learningState = after.learningState
            log = after.log
        } else {
            adopt(all, scheduler: scheduler)
        }
        let suspended = Self.wholeSeconds(entry.date)
        if after.isSuspended, after.suspensionChanged == suspended, (suspensionChanged ?? .distantPast) <= suspended {
            isSuspended = true
            suspensionChanged = suspended
        }
    }

    /// Replaces the log by `newLog`, which differs from it by a review, and the learning state with what that
    /// gives: replayed if the log reaches back to the first review, else counted.
    private mutating func adopt(_ newLog: [ReviewLogEntry], scheduler: Scheduler) {
        if hasCompleteLog {
            let replayed = scheduler.replaying(newLog, of: self)
            learningState = replayed.learningState
            log = replayed.log
        } else {
            let difference = newLog.count - log.count
            if var state = learningState {
                state.reviews = max(0, state.reviews + difference)
                learningState = state
            }
            log = newLog
        }
    }

    private static func wholeSeconds(_ date: Date) -> Date {
        Date(timeIntervalSince1970: date.timeIntervalSince1970.rounded(.down))
    }
}
