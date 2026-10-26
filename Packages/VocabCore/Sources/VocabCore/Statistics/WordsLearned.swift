import Foundation

/// How many words the learner has learned, in whole words: the words whose Word → Meaning card (a card without a
/// kind, from a deck of older versions, is one too) has left learning (is in the review phase) and is not
/// suspended. A card in learning or relearning does not count: a lapse takes a word out until it is learned again.
/// The production card (Meaning → Word) is the same word the other way round and counts nothing.
///
/// `wordsAtDayStart` is the same count from the state of each card before the day's reviews, so `gainToday` is
/// what the day added; a suspended card is in neither number, so suspending never makes a loss. Nothing is stored:
/// the decks, and the moment, give the numbers. The sum of recall probabilities, `MemoryEstimate`, stays beside it
/// as the detail.
///
/// A word held by several decks, or twice by one (the same `WordKey`), is one word, learned when any card that holds
/// it is. A card without a word key is a word of its own.
public struct WordsLearned: Hashable, Sendable {
    /// The words learned now.
    public var words: Int
    /// The words that were learned when the study day began.
    public var wordsAtDayStart: Int

    /// A learned card with a word key, so that decks count a word once.
    struct Held: Hashable, Sendable {
        var key: WordKey?
        var now: Bool
        var atStart: Bool
    }

    /// The cards `words` is made of, learned now or at the day's start. Empty for a total.
    var held: [Held] = []

    public init(words: Int, wordsAtDayStart: Int) {
        self.words = words
        self.wordsAtDayStart = wordsAtDayStart
    }

    /// The words of `deck` at `now`, for the study day `calendar` puts `now` in.
    public init(deck: Deck, at now: Date, calendar: StudyCalendar) {
        let start = calendar.start(ofDay: calendar.dayNumber(for: now))
        let scheduler = Scheduler(learningOptions: deck.learningOptions, calendar: calendar)
        var held: [Held] = []
        for card in deck.cards where !card.isSuspended && card.kind != .production {
            let learnedNow = card.learningState?.phase == .review
            let learnedAtStart = scheduler.standing(card, atStartOf: start, now: now).learningState?.phase == .review
            if learnedNow || learnedAtStart {
                held.append(Held(key: WordKey(card: card), now: learnedNow, atStart: learnedAtStart))
            }
        }
        self = Self.tally(held)
        self.held = held
    }

    /// The decks together, a word held more than once counted once.
    public static func total(_ decks: [WordsLearned]) -> WordsLearned {
        var total = tally(decks.flatMap(\.held))
        total.held = []
        return total
    }

    private static func tally(_ held: [Held]) -> WordsLearned {
        var now = 0
        var atStart = 0
        var keyed: [(key: WordKey, held: Held)] = []
        for card in held {
            guard let key = card.key else {
                if card.now { now += 1 }
                if card.atStart { atStart += 1 }
                continue
            }
            keyed.append((key, card))
        }
        var learnedWords = Set<Int>()
        var wordsAtStart = Set<Int>()
        for (group, entry) in zip(WordKey.groups(of: keyed.map(\.key)), keyed) {
            if entry.held.now { learnedWords.insert(group) }
            if entry.held.atStart { wordsAtStart.insert(group) }
        }
        return WordsLearned(words: now + learnedWords.count, wordsAtDayStart: atStart + wordsAtStart.count)
    }

    /// What the day added: now minus the day's start; negative after a lapse that is not made up.
    public var gainToday: Int { words - wordsAtDayStart }

    /// The gain to show, "+N today": `nil` unless it is above 0.
    public var shownGain: Int? { gainToday > 0 ? gainToday : nil }
}
