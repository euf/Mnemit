import Foundation
import VocabCore

/// Where the learner stands in the day, as the headline of Today, the widget and the Mac's help say it. The
/// figures come from `DailyProgress`, or from a widget snapshot that holds the same three numbers.
///
/// Before the first round the line is the time to keep the streak, "≈ 2 min to keep your streak"; once the
/// last round is done, "Ring closed"; in between there is none, and the screens say the cards left. Rounds are
/// the unit the day's time is learned in and never show (`references/learning-flow.md`).
struct RoundStatus: Equatable, Sendable {
    /// The rounds the day holds; 0 for a day without a plan.
    var rounds: Int
    var roundsDone: Int
    /// The minutes to the end of the round the learner is in; `nil` once the rounds are done.
    var minutesToNext: Int?

    init(rounds: Int, roundsDone: Int, minutesToNext: Int?) {
        self.rounds = max(0, rounds)
        self.roundsDone = max(0, roundsDone)
        self.minutesToNext = minutesToNext
    }

    init(_ progress: DailyProgress) {
        self.init(rounds: progress.rounds, roundsDone: progress.roundsDone, minutesToNext: progress.minutesToNextRound)
    }

    /// Whether the day has a plan cut into rounds.
    var hasRounds: Bool { rounds > 0 }

    /// Every round of the day is done: the ring is closed.
    var isClosed: Bool { rounds > 0 && roundsDone >= rounds }

    /// The first round keeps the streak, so it is kept once one is done, or when the plan was empty.
    var isStreakKept: Bool { rounds == 0 || roundsDone > 0 }

    /// The first thing the day says: "≈ 2 min to keep your streak" before the first round, "Ring closed" once
    /// the rounds are done; `nil` in between and for a day without rounds.
    var title: LocalizedStringResource? {
        if isClosed { return LocalizedStringResource("Ring closed") }
        if rounds > 0, roundsDone == 0, let minutesToNext {
            return LocalizedStringResource("\(Format.timeLeft(minutes: minutesToNext)) to keep your streak")
        }
        return nil
    }

    /// The title as a string.
    var line: String? { title.map { String(localized: $0) } }
}

extension MemoryEstimate {
    /// "28 words in memory" for `words` shown, what the widget keeps of the estimate; `nil` while there are none.
    static func wordsLine(_ words: Int) -> LocalizedStringResource? {
        words > 0 ? LocalizedStringResource("\(words) words in memory") : nil
    }

    /// "28 words in memory", the words the learner would recall now; `nil` while there are none to show.
    var wordsLine: LocalizedStringResource? { Self.wordsLine(shownWords) }

    /// "+15 today", what the day added; `nil` when it added nothing.
    var gainLine: LocalizedStringResource? {
        shownGain > 0 ? LocalizedStringResource("+\(shownGain) today") : nil
    }

    /// "28 words in memory · +15 today", or the first part alone.
    var line: String? {
        guard let wordsLine else { return nil }
        return [String(localized: wordsLine), gainLine.map { String(localized: $0) }].compactMap { $0 }.joined(separator: " · ")
    }

    /// "50 words in memory!" on the day the number passed a milestone.
    var milestoneLine: LocalizedStringResource? {
        milestoneReachedToday.map { LocalizedStringResource("\($0) words in memory!") }
    }
}
