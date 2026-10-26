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
///
/// A word held by several decks, or twice by one, is one word: `total(_:)` counts it once, at the
/// highest recall probability of the cards that hold it (`WordKey`).
public struct MemoryEstimate: Hashable, Sendable {
    /// The thresholds worth a mention, in words.
    public static let milestones = [50, 100, 250, 500, 1000, 1500, 2000, 3000, 5000]

    /// The words in memory now.
    public var words: Double
    /// The words in memory when the study day began, from the state of each card before the
    /// day's reviews.
    public var wordsAtDayStart: Double

    /// What one learned card with a word key adds to `words` and `wordsAtDayStart`, for the
    /// total of several decks to count a word once.
    struct Recall: Hashable, Sendable {
        var key: WordKey
        var now: Double
        var atStart: Double
    }

    /// The cards with a word key that `words` is made of. Empty for a total, and for a value made
    /// from numbers.
    var recalls: [Recall] = []

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
        var recalls: [Recall] = []
        for card in deck.cards where !card.isSuspended && card.kind != .production {
            var recallNow = 0.0
            var recallAtStart = 0.0
            if let state = card.learningState {
                recallNow = scheduler.recallProbability(of: state, at: now)
                words += recallNow
            }
            // The card as it stood when the day began (`Scheduler.standing(_:atStartOf:now:)`).
            let before = scheduler.standing(card, atStartOf: start, now: now)
            if let state = before.learningState {
                recallAtStart = scheduler.recallProbability(of: state, at: start)
                atStart += recallAtStart
            }
            if card.learningState != nil || before.learningState != nil, let key = WordKey(card: card) {
                recalls.append(Recall(key: key, now: recallNow, atStart: recallAtStart))
            }
        }
        self.init(words: words, wordsAtDayStart: atStart)
        self.recalls = recalls
    }

    /// The decks together: their words add up, except that a word the decks hold more than once
    /// (the same `WordKey`) counts once, at the highest recall probability among its cards, now
    /// and at the start of the day.
    public static func total(_ estimates: [MemoryEstimate]) -> MemoryEstimate {
        var words = estimates.reduce(0) { $0 + $1.words }
        var wordsAtDayStart = estimates.reduce(0) { $0 + $1.wordsAtDayStart }
        // Per word: what its cards add up to, and the highest of them. A word of one card loses nothing.
        let recalls = estimates.flatMap(\.recalls)
        var sums: [Int: (now: Double, atStart: Double)] = [:]
        var highest: [Int: (now: Double, atStart: Double)] = [:]
        for (group, recall) in zip(WordKey.groups(of: recalls.map(\.key)), recalls) {
            let sum = sums[group] ?? (0, 0)
            sums[group] = (sum.now + recall.now, sum.atStart + recall.atStart)
            let top = highest[group] ?? (0, 0)
            highest[group] = (max(top.now, recall.now), max(top.atStart, recall.atStart))
        }
        for (group, sum) in sums {
            let top = highest[group] ?? (0, 0)
            words -= sum.now - top.now
            wordsAtDayStart -= sum.atStart - top.atStart
        }
        return MemoryEstimate(words: words, wordsAtDayStart: wordsAtDayStart)
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
