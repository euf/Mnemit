import Foundation

/// The week's work in words, the number learners compare (`references/competition-metric.md`): the different words
/// answered right (Hard, Good or Easy) on the last 7 study days, today included, new or reviewed, each once. A card that
/// comes back three times in the week counts once, a card answered only Again not at all; a word held by several cards or
/// decks (the same `WordKey`) is one word, a card without a key a word of its own. The reviews of a deleted card and of a
/// paused deck count, as everywhere the work is counted.
///
/// Beside it the median seconds of the same days' answers, from the times the log holds (`ReviewLogEntry.duration`): a
/// learner who taps through shows under 2 s, a typical answer takes 5 to 15. And the most words right in any 7 days
/// before today, which this week either beats or doesn't.
public struct WordsRight: Hashable, Sendable {
    /// The study days of a week: today and the six before it.
    public static let days = 7

    /// The words right on the last 7 study days, today included.
    public var words: Int
    /// The median seconds of an answer on those days, `nil` while none of their answers has a time.
    public var secondsPerAnswer: Double?
    /// The most words right in any 7 days that ended before today.
    public var bestBefore: Int

    public init(words: Int = 0, secondsPerAnswer: Double? = nil, bestBefore: Int = 0) {
        self.words = words
        self.secondsPerAnswer = secondsPerAnswer
        self.bestBefore = bestBefore
    }

    /// The most words right in any 7 days so far, this week's included.
    public var best: Int { max(words, bestBefore) }

    /// Whether this week holds more words right than any earlier one, of which there was one with a word right.
    public var isBestWeek: Bool { bestBefore > 0 && words > bestBefore }

    /// One deck's cards answered right, by study day: each day's cards (indices of `Deck.trainingCards`) with an answer
    /// other than Again on it, and the word key of every such card that has one.
    struct Answers: Sendable {
        var byDay: [Int: [Int]] = [:]
        var keys: [Int: WordKey] = [:]
    }

    /// The words answered right on each study day across the decks, a word as a number: a word key's group
    /// (`WordKey.groups(of:)`) for the cards that have one, a number of its own for each card that has none.
    static func words(byDay decks: [Answers]) -> [Int: Set<Int>] {
        var keyed: [(deck: Int, card: Int, key: WordKey)] = []
        for (deck, answers) in decks.enumerated() {
            for (card, key) in answers.keys { keyed.append((deck, card, key)) }
        }
        var word: [Int: [Int: Int]] = [:]
        for (entry, group) in zip(keyed, WordKey.groups(of: keyed.map(\.key))) {
            word[entry.deck, default: [:]][entry.card] = group
        }
        var next = keyed.count
        var byDay: [Int: Set<Int>] = [:]
        for (deck, answers) in decks.enumerated() {
            var own: [Int: Int] = [:]
            for (day, cards) in answers.byDay {
                for card in cards {
                    let number: Int
                    if let group = word[deck]?[card] {
                        number = group
                    } else if let known = own[card] {
                        number = known
                    } else {
                        number = next
                        own[card] = next
                        next += 1
                    }
                    byDay[day, default: []].insert(number)
                }
            }
        }
        return byDay
    }

    /// The words right on the 7 study days that end with `day`.
    static func count(_ byDay: [Int: Set<Int>], endingOn day: Int) -> Int {
        var words = Set<Int>()
        for past in (day - days + 1)...day {
            if let right = byDay[past] { words.formUnion(right) }
        }
        return words.count
    }

    /// The middle of `seconds`, the lower of the two middle ones for an even count; `nil` for none.
    static func median(_ seconds: [Double]) -> Double? {
        guard !seconds.isEmpty else { return nil }
        let sorted = seconds.sorted()
        return sorted[(sorted.count - 1) / 2]
    }
}
