import Foundation

/// Per-deck learning options.
///
/// A deck holds only values within the ranges below: building a deck from its parts
/// (`Deck.init(learningOptions:cards:progress:contentModified:)`) and
/// `DeckChange.changingLearningOptions` clamp them with `sanitize()`.
public struct LearningOptions: Hashable, Sendable {
    /// Recall probability at which a card becomes due again (FSRS "desired retention").
    public var targetRecall: Double = 0.9
    /// Upper bound for review intervals in days.
    public var maximumInterval: Int = 36500
    /// Steps (`.good` grades) a card in (re)learning needs to reach the review phase.
    public var steps: Int = 2
    /// Maximum number of cards per session; `nil` means unlimited.
    public var cardsPerSession: Int? = 100
    /// Maximum number of never-studied cards a study day introduces, not counting new
    /// production cards (`newProductionPerSession`); `nil` means unlimited. Cards whose
    /// first review fell on the current study day count against it, so every session of
    /// the day takes from one quota. The name keeps `deck.json` readable: it said "per
    /// session" when the limit still restarted with each session.
    public var newCardsPerSession: Int? = nil
    /// Maximum number of never-studied production cards (`CardKind.production`) a study
    /// day introduces, counted like `newCardsPerSession`; 0 asks none, `nil` means
    /// unlimited.
    public var newProductionPerSession: Int? = 7
    /// Days the interval of a note's recognition card must have reached before its
    /// production card is introduced; 0 never holds production cards back.
    public var productionUnlockDays: Int = 21
    /// In which order a session introduces new cards when it can't take all of them.
    public var newCardOrder: NewCardOrder = .deckOrder
    public var caseSensitive: Bool = true
    /// Spreads review intervals slightly so cards learned together don't stay clustered.
    public var fuzzing: Bool = true
    public var parameters: FSRSParameters = .default
    /// Share of the stability FSRS adds that a card keeps after recalling it in a revealed
    /// review (`ReviewMode.revealed`); a typed review keeps all of it. 1 treats a revealed
    /// review like any other, as Anki does; the lower bound, a third, is the damping of
    /// ADR 0004. Applies where the scheduler rates a review, replays a log and in the
    /// optimizer's model; see ADR 0005.
    public var revealedRecallWeight: Double = 1
    /// Whether the optimizer also learns from revealed reviews. Off, only typed reviews
    /// are its targets, as with ADR 0004.
    public var optimizeFromRevealed: Bool = true
    /// Lapses (Again on a card in the review phase) after which a study session suspends
    /// the card as a leech, and after every further multiple of it; 0 never does. A card is
    /// a leech from that many lapses on, resumed or not: `Card.isLeech(threshold:)`.
    public var leechThreshold: Int = 8

    public init() {}

    public static let targetRecallRange: ClosedRange<Double> = 0.7...0.97
    public static let maximumIntervalRange: ClosedRange<Int> = 30...36500
    public static let stepsRange: ClosedRange<Int> = 1...5
    /// For `cardsPerSession` and `newCardsPerSession` when they are limited.
    public static let sessionLimitRange: ClosedRange<Int> = 1...9999
    /// For `newProductionPerSession` when it is limited: unlike the other limits, 0 is valid.
    public static let productionLimitRange: ClosedRange<Int> = 0...9999
    public static let productionUnlockDaysRange: ClosedRange<Int> = 0...365
    /// For `leechThreshold`; 0 is off.
    public static let leechThresholdRange: ClosedRange<Int> = 0...99
    /// From the damping of ADR 0004 (a third) to none.
    public static let revealedRecallWeightRange: ClosedRange<Double> = (1.0 / 3)...1
}

extension LearningOptions {
    /// What a card's memory (stability and difficulty) is computed with. A card's memory
    /// is replayed from its review log when this changes: `DeckChange` and merges.
    struct MemoryModel: Hashable, Sendable {
        var parameters: FSRSParameters
        var revealedRecallWeight: Double
    }

    var memoryModel: MemoryModel {
        MemoryModel(parameters: parameters, revealedRecallWeight: revealedRecallWeight)
    }
}

/// The order in which a study session takes new cards when a limit leaves some out.
public enum NewCardOrder: String, Sendable, CaseIterable {
    /// As the deck lists them.
    case deckOrder
    /// By creation date, the newest first; cards created together stay in deck order.
    case newestFirst
}

extension LearningOptions {
    /// Clamps values into the ranges the learning options offer, for options of a deck
    /// built from its parts (from hand-edited or corrupt files, too) and for new options
    /// set on a deck.
    mutating func sanitize() {
        if !targetRecall.isFinite { targetRecall = LearningOptions().targetRecall }
        targetRecall = targetRecall.clamped(to: Self.targetRecallRange)
        maximumInterval = maximumInterval.clamped(to: Self.maximumIntervalRange)
        steps = steps.clamped(to: Self.stepsRange)
        cardsPerSession = cardsPerSession?.clamped(to: Self.sessionLimitRange)
        newCardsPerSession = newCardsPerSession?.clamped(to: Self.sessionLimitRange)
        newProductionPerSession = newProductionPerSession?.clamped(to: Self.productionLimitRange)
        productionUnlockDays = productionUnlockDays.clamped(to: Self.productionUnlockDaysRange)
        leechThreshold = leechThreshold.clamped(to: Self.leechThresholdRange)
        if !revealedRecallWeight.isFinite { revealedRecallWeight = LearningOptions().revealedRecallWeight }
        revealedRecallWeight = revealedRecallWeight.clamped(to: Self.revealedRecallWeightRange)
    }
}

/// A collection of cards together with its learning options and progress, stored
/// as one package (see `DeckFile`).
///
/// Cards and learning options change only through `apply(_:at:calendar:)`, which
/// keeps `progress` and `contentModified` in step with the cards.
public struct Deck: Hashable, Sendable {
    public internal(set) var learningOptions: LearningOptions
    public internal(set) var cards: [Card]
    /// One daily snapshot per study day on which the deck changed, oldest first.
    public internal(set) var progress: [DailySnapshot]
    /// When the content last changed, in whole seconds: cards added, removed, edited or
    /// reset, or the learning options. Reviews and suspending or resuming a card leave
    /// it, so a merge can tell which version holds the newer content
    /// (`DeckChange.merging`). `nil` until the first such change since the deck was
    /// created or saved by an app version without it.
    public internal(set) var contentModified: Date?

    /// Why a deck can't be built from its parts.
    enum Error: Swift.Error, Equatable {
        /// `card` has the ID of a card before it.
        case duplicateCardID(Card)
    }

    /// An empty deck with the default learning options.
    public init() {
        learningOptions = LearningOptions()
        cards = []
        progress = []
        contentModified = nil
    }

    /// A deck built from its parts, as `DeckFile` reads it or `LegacyImporter` converts
    /// it. The learning options are clamped like those set on a deck
    /// (`DeckChange.changingLearningOptions`); cards keep their order.
    ///
    /// - Throws: `Error.duplicateCardID` for the first card whose ID is already taken:
    ///   `apply(_:at:calendar:)` and `ReviewLogEncoder` rely on unique IDs.
    init(
        learningOptions: LearningOptions = LearningOptions(),
        cards: [Card],
        progress: [DailySnapshot] = [],
        contentModified: Date? = nil
    ) throws {
        var ids = Set<Card.ID>()
        if let duplicate = cards.first(where: { !ids.insert($0.id).inserted }) {
            throw Error.duplicateCardID(duplicate)
        }
        var learningOptions = learningOptions
        learningOptions.sanitize()
        self.learningOptions = learningOptions
        self.cards = cards
        self.progress = progress
        self.contentModified = contentModified
    }

    public func index(of id: Card.ID) -> Int? {
        cards.firstIndex { $0.id == id }
    }

    public func card(withID id: Card.ID) -> Card? {
        index(of: id).map { cards[$0] }
    }

    /// The number of cards due at `date`.
    public func dueCount(at date: Date) -> Int {
        cards.reduce(0) { $0 + ($1.isDue(at: date) ? 1 : 0) }
    }

    /// The number of suspended cards, see `Card.isSuspended`.
    public var suspendedCount: Int {
        cards.reduce(0) { $0 + ($1.isSuspended ? 1 : 0) }
    }

    /// Whether `card` is a leech by the deck's `LearningOptions.leechThreshold`.
    public func isLeech(_ card: Card) -> Bool {
        card.isLeech(threshold: learningOptions.leechThreshold)
    }

    /// The probability of recalling `card` at `now` with the deck's learning options,
    /// see `Scheduler.recallProbability(of:at:)`; `nil` for a new card.
    public func recallProbability(of card: Card, at now: Date, calendar: StudyCalendar) -> Double? {
        card.learningState.map {
            Scheduler(learningOptions: learningOptions, calendar: calendar).recallProbability(of: $0, at: now)
        }
    }

    /// Cards with the same question as `question`, see `CardText.key(forQuestion:)`.
    public func cards(withQuestion question: String) -> [Card] {
        let key = CardText.key(forQuestion: question)
        guard !key.isEmpty else { return [] }
        return cards.filter { CardText.key(forQuestion: $0.question) == key }
    }

    /// Records the current distribution of cards as the snapshot for `day`.
    mutating func updateProgress(day: Int) {
        let snapshot = DailySnapshot(day: day, bins: StabilityBins.histogram(of: cards))
        if let last = progress.last, last.day == day {
            progress[progress.count - 1] = snapshot
        } else if let last = progress.last, last.day > day {
            // Clock moved backwards; never reorder existing snapshots.
            return
        } else {
            progress.append(snapshot)
        }
    }
}
