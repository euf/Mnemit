import Foundation

/// How many words the learner would recall right now, straight from FSRS: the sum, over the
/// recognition cards that have been studied and are not suspended, of the probability of
/// recalling each (`Scheduler.recallProbability(of:at:)`). It is the model's own prediction,
/// so it grows when the learner learns, falls when days pass without reviews and grows back
/// with the reviews. Nothing is stored: a deck, and the moment, give the number.
///
/// A word is its recognition card (a card without a kind, from a deck of older versions,
/// is one too); a production card is the same word the other way round and counts nothing, so
/// a word with two cards counts once. A card that has never been reviewed counts nothing,
/// one in learning or relearning counts by the same function from its state.
///
/// The recall probability counts whole study days since the last review, as everywhere in the
/// app: a card reviewed today is at 1 for the rest of the day, and one that wasn't is at the
/// same value from the day's start to its end. So the number falls at the study day's change
/// (04:00), not within the day, and the gain of a day is the cards reviewed that day coming
/// back to 1, and the new ones: zero on a day without reviews. The fall of a day without study
/// shows against the day before.
public struct MemoryEstimate: Hashable, Sendable {
    /// The thresholds worth a mention, in words.
    public static let milestones = [50, 100, 250, 500, 1000, 1500, 2000, 3000, 5000]

    /// The words in memory now.
    public var words: Double
    /// The words in memory when the study day began, from the state of each card before the
    /// day's reviews.
    public var wordsAtDayStart: Double

    public init(words: Double, wordsAtDayStart: Double) {
        self.words = words
        self.wordsAtDayStart = wordsAtDayStart
    }

    /// The estimate of `deck` at `now`, for the study day `calendar` puts `now` in.
    public init(deck: Deck, at now: Date, calendar: StudyCalendar) {
        let start = calendar.start(ofDay: calendar.dayNumber(for: now))
        let scheduler = Scheduler(learningOptions: deck.learningOptions, calendar: calendar)
        var words = 0.0
        var atStart = 0.0
        for card in deck.cards where !card.isSuspended && card.kind != .production {
            if let state = card.learningState {
                words += scheduler.recallProbability(of: state, at: now)
            }
            // The card as it stood when the day began, as `DeckActivity.plan(onDayOf:calendar:)`
            // takes it: replayed from the reviews before the day, only when it has one today and
            // its log reaches back to its first review. ponytail: a card with an incomplete log,
            // reviewed today, stays as it is now, at 1 at the day's start, so it adds no gain;
            // a gain is never overstated.
            var before = card
            let earlier = card.log.prefix { $0.date < start }
            if card.hasCompleteLog, earlier.count < card.log.count, card.log[earlier.count].date <= now {
                before = scheduler.replaying(Array(earlier), of: card)
            }
            if let state = before.learningState {
                atStart += scheduler.recallProbability(of: state, at: start)
            }
        }
        self.init(words: words, wordsAtDayStart: atStart)
    }

    /// The decks together: their words add up, a word is in one deck.
    public static func total(_ estimates: [MemoryEstimate]) -> MemoryEstimate {
        MemoryEstimate(
            words: estimates.reduce(0) { $0 + $1.words },
            wordsAtDayStart: estimates.reduce(0) { $0 + $1.wordsAtDayStart })
    }

    /// What the day added: now minus the day's start.
    public var gainToday: Double { words - wordsAtDayStart }

    /// The words to show, rounded down: "≈ 412" must not promise more than the model says.
    public var shownWords: Int { Int(words.rounded(.down)) }

    /// The gain to show, rounded to the nearest whole word.
    public var shownGain: Int { Int(gainToday.rounded()) }

    /// The first milestone above the words now; `nil` past the last.
    public var nextMilestone: Int? {
        Self.milestones.first { Double($0) > words }
    }

    /// The highest milestone crossed today, `wordsAtDayStart < m ≤ words`; `nil` if none.
    public var milestoneReachedToday: Int? {
        Self.milestones.last { wordsAtDayStart < Double($0) && Double($0) <= words }
    }
}
