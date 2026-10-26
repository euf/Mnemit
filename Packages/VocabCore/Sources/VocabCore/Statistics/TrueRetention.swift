import Foundation

/// How often the learner recalled cards that had been left to the review phase, by
/// period, like the "True Retention" table of Anki's statistics.
///
/// Counts the reviews of cards in the review phase, on a later study day than the
/// previous review of the card: `.hard`, `.good` and `.easy` pass, `.again` fails.
/// Left out are the first review of a new card, the steps of learning and relearning,
/// and a repeat on the same study day: none of them tests a memory that had a day to fade.
///
/// The log holds no phase and no interval, so the phase and the interval a review found
/// come from replaying the card's log with the deck's learning options, the way
/// `DeckChange.merging` replays it. Options changed since a review move the replay away
/// from what the device scheduled then: the steps change which reviews count, the
/// parameters and the target recall the young/mature split near `matureInterval`. Cards
/// whose log doesn't reach back to their first review, see `Card.hasCompleteLog`, can't
/// be replayed and are left out.
public struct TrueRetention: Hashable, Sendable {
    /// Study days back from today that a table counts. A review of the study day
    /// `today - n` belongs to the period if `n` is within `dayOffsets`.
    public enum Period: CaseIterable, Sendable {
        case today, yesterday, last7Days, last30Days, last365Days

        /// Today is offset 0; the last 7 days are today and the six before it.
        public var dayOffsets: ClosedRange<Int> {
            switch self {
            case .today: 0...0
            case .yesterday: 1...1
            case .last7Days: 0...6
            case .last30Days: 0...29
            case .last365Days: 0...364
            }
        }
    }

    /// Reviews counted by outcome.
    public struct Tally: Hashable, Sendable {
        public var passed = 0
        public var failed = 0

        public var reviews: Int { passed + failed }

        /// The share of passed reviews; `nil` without reviews.
        public var retention: Double? {
            reviews > 0 ? Double(passed) / Double(reviews) : nil
        }

        mutating func add(passed isPassed: Bool) {
            if isPassed { passed += 1 } else { failed += 1 }
        }
    }

    /// Reviews of cards whose scheduled interval was shorter than `matureInterval`,
    /// those whose interval was at least that long, and both together.
    public struct Split: Hashable, Sendable {
        public var young = Tally()
        public var mature = Tally()

        public var total: Tally {
            Tally(passed: young.passed + mature.passed, failed: young.failed + mature.failed)
        }

        mutating func add(passed: Bool, isMature: Bool) {
            if isMature { mature.add(passed: passed) } else { young.add(passed: passed) }
        }
    }

    /// One split per period.
    public struct Table: Hashable, Sendable {
        private var splits: [Period: Split] = [:]

        public subscript(period: Period) -> Split { splits[period] ?? Split() }

        mutating func add(passed: Bool, isMature: Bool, daysAgo: Int) {
            for period in Period.allCases where period.dayOffsets.contains(daysAgo) {
                splits[period, default: Split()].add(passed: passed, isMature: isMature)
            }
        }
    }

    /// Anki's threshold: a card is mature once its scheduled interval reaches 21 days.
    public static let matureInterval = 21

    public private(set) var all = Table()
    /// What the deck aims at, `LearningOptions.targetRecall`, to read the figures against.
    public let desiredRetention: Double

    /// The figures of `deck` for the study day of `now`.
    public init(of deck: Deck, at now: Date, calendar: StudyCalendar) {
        desiredRetention = deck.learningOptions.targetRecall
        let scheduler = Scheduler(learningOptions: deck.learningOptions, calendar: calendar)
        let today = calendar.dayNumber(for: now)

        for card in deck.cards where card.hasCompleteLog {
            var replayed = card
            replayed.resetLearningState()
            for entry in card.log {
                if let found = replayed.learningState, found.phase == .review,
                    calendar.days(from: found.lastReview, to: entry.date) >= 1
                {
                    let daysAgo = today - calendar.dayNumber(for: entry.date)
                    let isPassed = entry.grade.isRecall
                    let isMature = calendar.days(from: found.lastReview, to: found.due) >= Self.matureInterval
                    all.add(passed: isPassed, isMature: isMature, daysAgo: daysAgo)
                }
                var random = Scheduler.random(forReviewOf: card.id, at: entry.date)
                replayed = scheduler.review(replayed, grade: entry.grade, at: entry.date, mode: entry.mode, using: &random)
            }
        }
    }
}
