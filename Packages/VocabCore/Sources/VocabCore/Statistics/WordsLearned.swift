import Foundation

/// How many words the learner has learned, in whole words: the words whose Word → Meaning card (a card without a
/// kind, from a deck of older versions, is one too) has left learning (is in the review or relearning phase) and is
/// not suspended. A lapse takes no word out: the card is relearning, and the word stays learned, as in the medals and
/// the ledger (`leftLearning(in:calendar:)`, `cumulative`), so the headline and the gain are one count.
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
            let learnedNow = Self.hasLeftLearning(card.learningState)
            let learnedAtStart = Self.hasLeftLearning(scheduler.standing(card, atStartOf: start, now: now).learningState)
            if learnedNow || learnedAtStart {
                held.append(Held(key: WordKey(card: card), now: learnedNow, atStart: learnedAtStart))
            }
        }
        self = Self.tally(held)
        self.held = held
    }

    /// Whether a card in this state has left learning: review or relearning. The one rule of every count of words.
    static func hasLeftLearning(_ state: LearningState?) -> Bool {
        guard let phase = state?.phase else { return false }
        return phase != .learning
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

    /// The counts of words learned that earn a medal: 10, 50, 100, 250, 500 and 1000, then every 1000.
    public static func milestones(upTo count: Int) -> [Int] {
        [10, 50, 100, 250, 500, 1000].filter { $0 <= count } + (count >= 2000 ? Array(stride(from: 2000, through: count, by: 1000)) : [])
    }

    /// The first milestone above `count`.
    public static func nextMilestone(after count: Int) -> Int {
        [10, 50, 100, 250, 500, 1000].first { $0 > count } ?? (count / 1000 + 1) * 1000
    }

    /// The studied word cards of `deck` that have left learning at some time, in review or relearning now, suspended
    /// and production cards apart, each with the study day it first did: from its log by the rule of the steps
    /// (`Steps`); `nil` when the log doesn't reach back to the first review, which a card imported without its history
    /// lacks, so the day is unknown.
    static func leftLearning(in deck: Deck, calendar: StudyCalendar) -> [(key: WordKey?, day: Int?)] {
        var left: [(key: WordKey?, day: Int?)] = []
        for card in deck.cards where !card.isSuspended && card.kind != .production {
            guard hasLeftLearning(card.learningState) else { continue }
            var day: Int?
            if card.hasCompleteLog {
                var steps = Steps(required: deck.learningOptions.steps)
                for entry in card.log {
                    steps.apply(entry.grade)
                    if steps.areEnough {
                        day = calendar.dayNumber(for: entry.date)
                        break
                    }
                }
            }
            left.append((WordKey(card: card), day))
        }
        return left
    }

    /// The words that had left learning by the end of each study day from `first` through `today`, a word held by
    /// several cards counted once, from the day its first card left (a lapse takes none back, so a medal for a
    /// count is never lost to one). A word of unknown day counts from `first`.
    static func cumulative(_ left: [(key: WordKey?, day: Int?)], from first: Int, through today: Int) -> [Int: Int] {
        func clamped(_ day: Int?) -> Int { min(max(day ?? first, first), today) }
        var perDay: [Int: Int] = [:]
        var keyed: [(key: WordKey, day: Int)] = []
        for entry in left {
            if let key = entry.key { keyed.append((key, clamped(entry.day))) } else { perDay[clamped(entry.day), default: 0] += 1 }
        }
        var earliest: [Int: Int] = [:]
        for (group, entry) in zip(WordKey.groups(of: keyed.map(\.key)), keyed) {
            earliest[group] = min(earliest[group] ?? entry.day, entry.day)
        }
        for day in earliest.values { perDay[day, default: 0] += 1 }
        var total = 0
        var byDay: [Int: Int] = [:]
        for day in first...max(first, today) {
            total += perDay[day] ?? 0
            byDay[day] = total
        }
        return byDay
    }

    /// What the day added: now minus the day's start; negative only when a card was reset or a word set aside.
    public var gainToday: Int { words - wordsAtDayStart }

    /// The gain to show, "+N today": `nil` unless it is above 0.
    public var shownGain: Int? { gainToday > 0 ? gainToday : nil }
}
