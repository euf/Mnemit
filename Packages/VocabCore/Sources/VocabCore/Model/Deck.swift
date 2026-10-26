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
    /// Maximum number of cards in one session, which is the size of one segment of the study
    /// stream; `nil` means unlimited. The plan of the day, and the goal made of it, isn't
    /// capped by it: the stream takes the plan segment after segment.
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
    public var productionUnlockDays: Int = 7
    /// In which order a session introduces new cards when it can't take all of them.
    public var newCardOrder: NewCardOrder = .deckOrder
    /// Spreads review intervals slightly so cards learned together don't stay clustered.
    public var fuzzing: Bool = true
    public var parameters: FSRSParameters = .default
    /// Lapses (Again on a card in the review phase) after which a study session suspends
    /// the card as a leech, and after every further multiple of it; 0 never does. A card is
    /// a leech from that many lapses on, resumed or not: `Card.isLeech(threshold:)`.
    public var leechThreshold: Int = 8
    /// Whether the app fits `parameters` to the review log again from time to time and keeps
    /// the fit when it predicts the reviews better, see `ParameterRefit`.
    public var updatesParametersAutomatically: Bool = true
    /// The last time the app fitted the parameters by itself, `nil` before the first time.
    /// Set by `ParameterRefit.Result`; the learner's own "Compute from Review Log" leaves it.
    public var lastAutoFit: AutoFit?
    /// Whether the learner paused the deck: it takes no part in the day (plan, goal, rounds,
    /// time, admission of new cards, streak, words in memory, widget, reminders, the
    /// Study chain) but stays open to study by itself. It travels with the options, so a merge
    /// takes it from the version that changed them last, and resuming is the same change.
    public var isPaused: Bool = false

    /// One automatic fit of the parameters, kept or not.
    public struct AutoFit: Hashable, Sendable {
        /// When the fit ran, in whole seconds as `deck.json` keeps it.
        public var date: Date
        /// How many usable reviews the fit saw (`FSRSOptimizer.reviewCount`); the next fit
        /// waits for more of them.
        public var reviewCount: Int
        /// Whether the fitted parameters replaced the old ones; `false` when they fit
        /// the reviews no better, or the optimizer found none.
        public var adopted: Bool

        public init(date: Date, reviewCount: Int, adopted: Bool) {
            self.date = date
            self.reviewCount = reviewCount
            self.adopted = adopted
        }
    }

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
        if let fit = lastAutoFit { lastAutoFit?.reviewCount = max(0, fit.reviewCount) }
    }
}

/// A collection of cards together with its learning options and progress, stored
/// as one package (see `DeckFile`).
///
/// Cards and learning options change only through `apply(_:at:calendar:)`, which
/// keeps `progress`, `contentModified`, `learningOptionsChanged`, `deletedCards` and
/// `retiredCards` in step with them.
public struct Deck: Hashable, Sendable {
    public internal(set) var learningOptions: LearningOptions
    public internal(set) var cards: [Card]
    /// One daily snapshot per study day on which the deck changed, oldest first.
    public internal(set) var progress: [DailySnapshot]
    /// When the content last changed, in whole seconds: cards added, removed, edited or
    /// reset, or the learning options. Reviews and suspending or resuming a card leave
    /// it. A merge takes the order of the cards from the version with the later one, and
    /// settles by it what carries no stamp of its own, as in decks saved before
    /// `Card.contentChanged` (`DeckChange.merging`). `nil` until the first such change
    /// since the deck was created or saved by an app version without it.
    public internal(set) var contentModified: Date?
    /// When the learning options last changed, in whole seconds; `nil` until the first
    /// change since the deck was created or saved by an app version without it. A merge
    /// takes the options from the version that changed them last, so a change of the
    /// options survives edits of cards on the other device.
    public internal(set) var learningOptionsChanged: Date?
    /// The cards the learner deleted, with the time they did, in whole seconds. A merge
    /// tells a deleted card from one the other version doesn't have yet with it, and
    /// takes the card back if something was done to it after the deletion.
    /// `Deck.apply(_:at:calendar:)` keeps it: a card that is back in the deck is no
    /// longer in it.
    public internal(set) var deletedCards: [Card.ID: Date]
    /// The cards the learner deleted that had reviews, as they stood when they went, with their learning
    /// state and log: the reviews were real recall attempts. Only the day's done cards
    /// (`doneCards(onDayOf:calendar:)`, so a card done today stays done after its deletion), the reviews
    /// by day (`DeckActivity.reviewsByDay`) and the FSRS refit (`trainingCards`) see them; the plan, the
    /// counts, the browser, search, export and the other statistics do not. A card is here or in `cards`,
    /// never in both: `apply(_:at:calendar:)` retires a deleted card that has a log and takes a card out
    /// again that comes back. A merge joins them, see `DeckChange.merging`.
    public internal(set) var retiredCards: [Card]
    /// The images and sounds of the cards (`CardMedia`), the `media` folder of the package. Only
    /// `apply(_:at:calendar:)` changes them, and only by the files a change brings in or takes out
    /// again; see `DeckMedia` for what a package keeps.
    public internal(set) var media: DeckMedia

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
        learningOptionsChanged = nil
        deletedCards = [:]
        retiredCards = []
        media = DeckMedia()
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
        contentModified: Date? = nil,
        learningOptionsChanged: Date? = nil,
        deletedCards: [Card.ID: Date] = [:],
        retiredCards: [Card] = [],
        media: DeckMedia = DeckMedia()
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
        self.learningOptionsChanged = learningOptionsChanged
        self.deletedCards = deletedCards.filter { !ids.contains($0.key) }
        var retiredIDs = ids
        self.retiredCards = retiredCards.filter { retiredIDs.insert($0.id).inserted }
        self.media = media
    }

    public func index(of id: Card.ID) -> Int? {
        cards.firstIndex { $0.id == id }
    }

    public func card(withID id: Card.ID) -> Card? {
        index(of: id).map { cards[$0] }
    }

    /// The number of suspended cards, see `Card.isSuspended`.
    public var suspendedCount: Int {
        cards.reduce(0) { $0 + ($1.isSuspended ? 1 : 0) }
    }

    /// The newest batch of words: the cards whose `created` falls on the second of the
    /// deck's latest one, in deck order, without suspended cards. `deck-from-tsv` stamps one
    /// `created` per run, so a batch is what one run added, usually the words of the last
    /// lesson or two. Empty for a deck without cards. Meant for `Practice(practicing:at:)`.
    ///
    /// Cards added by hand in between start a batch of their own.
    public var newestBatchIDs: [Card.ID] {
        func second(_ card: Card) -> Int { Int(card.created.timeIntervalSince1970.rounded(.down)) }
        guard let newest = cards.map(second).max() else { return [] }
        return cards.filter { second($0) == newest && !$0.isSuspended }.map(\.id)
    }

    /// The cards graded `.again` at least once on the study day of `date`, in deck order,
    /// without suspended cards. Read from the review logs, so it holds across study
    /// streams and devices. Meant for `Practice(practicing:at:)`.
    public func mistakes(onDayOf date: Date, calendar: StudyCalendar) -> [Card.ID] {
        let day = calendar.dayNumber(for: date)
        return cards.filter { card in
            guard !card.isSuspended else { return false }
            for entry in card.log.reversed() {
                let entryDay = calendar.dayNumber(for: entry.date)
                if entryDay < day { break }
                if entryDay == day, entry.grade == .again { return true }
            }
            return false
        }.map(\.id)
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

    /// The cards whose reviews the FSRS refit trains on: the cards and the retired ones.
    public var trainingCards: [Card] {
        retiredCards.isEmpty ? cards : cards + retiredCards
    }

    /// The names of the media files some card names.
    public var namedMedia: Set<String> {
        cards.reduce(into: Set<String>()) { $0.formUnion($1.media.names) }
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
